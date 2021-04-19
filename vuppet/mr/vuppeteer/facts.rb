## 
# Manages Build and Puppet Facts for Mr
#

module Facts
  extend self

  @facts = nil
  @root_facts = []
  @instance_facts = []
  @requirements = []
  @generate = {}

  @meta_facets = {
    rdtd: ['__rdtd__', 'Redacted'],
    blok: ['__hblk__', 'Locked'],
    alts: ['__alts__', 'Duplicate'],
    updt: ['__updt__', 'Updated'],
  }

  ##
  # facts that can only be defined in Vagrantfile options
  @option_only_facts = [
    'mr_path',
    'root_path',
    'allowed_read_path', 'allowed_write_path',
    'localize_token', 'override_token',
  ]

  ##
  # facts that can only be defined in Vagrantfile options or local fact files
  # local fact files include, in order of loading:
  # - {localize_token}.{build_facts_file}.yaml and 
  # - developer_facts_file (~/.mr/developer.yaml)
  @developer_facts = [
    'pref_license_ident',
    'git_developer','ghc_developer','ghe_developer',
    'ghc_pat',
    'ghe_pat','ghe_host',
    'rhsm_user','rhsm_pass','rhsm_org', 'rhsm_key', 'rhsm_host',
  ]

  ##
  # facts that can only be defined in Vagrantfile options 
  # or non-developer local facts
  @local_only_facts = [
    'developer_facts_file',
    'load_developer_facts',
  ]

  # ##
  # #
  # @merge_facts = {
  #   'helpers' => true,
  # }

  @invalid_facts_message = 'Notice: Additional facts not a hash, skipping...'

  ##
  # sets root facts, must be done before ::init
  def self.roots(f)
    Vuppeteer::shutdown('Error: Cannot define root facts once any are set.', -1) if !@facts.nil?
    Vuppeteer::shutdown('Error: Non-hash passed as root facts.' -1) if !f.respond_to?(:to_h)
    @facts = MrUtils::string_keys(f.to_h)
    @root_facts = @facts.keys()
  end

  ##
  # load the inital facts file, remove invalid keys, and merge it in with root_facts
  def self.init()
    if (@facts)
      Vuppeteer::report('facts', '_main', 'root')
    else
      @facts = {}
    end
    Vuppeteer::trace('roots', @facts)
    FileManager::path_ensure("#{Mr::active_path}/facts", FileManager::allow_dir_creation?)
    self._instance_facts() if Vuppeteer::enabled?(:instance)
    self._local_facts() if Vuppeteer::enabled?(:local)
    self._project_facts()
    self._developer_facts() if Vuppeteer::enabled?(:developer)
  end

  def self.post_stack_init() #NOTE additional steps that have to happen after stack init
    self._stack_facts() if Vuppeteer::enabled?(:stack)
    self.ensure(@generate)
    @generate = nil
    self._validate_requirements()
  end

  def self.facts()
    @facts.clone()
  end

  def self.instance()
    #self._instance_facts() if Vuppeteer::enabled?(:instance)
    result = {}
    @instance_facts.each() do |f|
      result[f] = @facts[f] if @facts.has_key?(f)
    end
    result
  end

  def self.promote(f, v = nil)
    @instance_facts.push(f) if !@instance_facts.include?(f)
    #TODO update it in facts as well?
  end

  def self.demote(f)
    @instance_facts.delete(f)
    #TODO delete it from facts as well?
  end

  def self.fact?(match)
    return @facts&.has_key?(match) if !match.is_a?(Array) && !MrUtils::traversable?(match)
    begin
      MrUtils::search(match, @facts, true)
    rescue => e
      Vuppeteer::trace('fact? fail', __FILE__,__LINE__,match, @facts, e)
      return false
    end
    return true
  end

  def self.get(match, default = nil, critical = false)
    result = MrUtils::search(match, @facts, critical)
    #Vuppeteer::trace(result,@facts,match)
    return !result.nil? ? result : default
  end

  def self.load(source, flag = nil)
    if (source.is_a?(Array)) 
      source.each() do |s|
        f = self.load(s, flag)
        return f if f
      end
      return nil
    end
    begin
      return self.get(source[2..-1], nil, true) if source.start_with?(MrUtils::splitter)
      parts = FileManager::facet_split(source)
      path = parts[0].end_with?('.yaml') ? parts[0] : "#{parts[0]}.yaml"
      if (File.exist?("#{Mr::active_path}/#{path}"))
        internal_override = "External Mr using internal source for '#{source}' facts."
        Vuppeteer::say(internal_override) if Vuppeteer::external? && Vuppeteer::enabled?(:verbose)
        return FileManager::load_fact_yaml("#{Mr::active_path}/#{source}", flag)
      else
        return FileManager::load_fact_yaml(source, flag)
      end
    rescue => e
      VuppeteerUtils::meditate("#{e} for \"#{source}\"", flag, :prep)
      false
    end
  end

  def self.requirements(r = nil)
    Vuppeteer::shutdown('Error: Non-array passed as requirements.', -1) if !r.is_a?(Array)
    if (!r.nil?) 
      r.each do |v|
        @requirements += [v]
      end
    end
    @requirements
  end

  def self.asserts(f)
    Vuppeteer::shutdown('Error: Non-hash passed as asserts.', -1) if !f.is_a?(Hash)
    f.each do |k, v|
      @requirements.push({k => v}) 
    end
  end

  def self.register(f)
    Vuppeteer::shutdown('Error: Attempting to register generated values after init', -3) if @generate.nil?
    Vuppeteer::shutdown('Error: Attempting to register generated values with a non-Hash', -3) if !f.is_a?(Hash)
    @generate = @generate.merge(f)
  end

  def self.ensure(f)
    #Vuppeteer::trace('ensure facts', f)
    missing = {}
    storable = []
    v = Vuppeteer::enabled?(:verbose)
    f.each do |k, c|
      if (!self.fact?(k))
        missing[k] = c
        storable.push(k) if VuppeteerUtils::storable?(c)
        Vuppeteer.say(["testing fact #{k}... missing","  ... generating fact #{k}"], :prep) if v
      else
        Vuppeteer.say("testing fact #{k}... provided", :prep) if v
      end
    end
    new_facts = VuppeteerUtils::generate(missing)
    self._set(new_facts, 'generated')
    storable_new_facts = {}
    storable.each do |k|
      storable_new_facts[k] = new_facts[k]
    end
    #Vuppeteer::trace(storable, storable_new_facts)
    Vuppeteer::update_instance(storable_new_facts, true) if storable_new_facts.length > 0
  end

  def self.expose()
    Vuppeteer::say(Report::pop('facts'), :prep)
    Vuppeteer::say(
      [
        'Processed Facts:',
        MrUtils::inspect(self.facts(), true), 
        '----------------',
      ], :prep
    )
  end
#################################################################
  private
#################################################################
  def self._set(f, source = nil)
    return Vuppeteer::say(@invalid_facts_message, :prep) if !f.is_a?(Hash)
    @facts = {} if !@facts
    f.each do |k, v|
      sensitive = VuppeteerUtils::sensitive_fact?(k)
      s = source ? "#{source}::" : ''
      Vuppeteer::mark_sensitive(v) if Vuppeteer::enabled?(:autofilter) && sensitive
      rooted = @root_facts.any? {|r| r == k }
      has_fact = @facts.has_key?(k)
      if (rooted)
        Vuppeteer::say("Notice: New fact #{s}#{k} is rooted...", :prep)
        self._set_as(:blok, k, v)
      elsif (@instance_facts.any?(k))
        Vuppeteer::say("Notice: Updating instance fact #{s}#{k} ...", :prep) if @facts.has_key?(k)
        self._set_as(:updt, k, @facts[k]) if @facts.has_key?(k)
        @facts[k] = v
      elsif (!rooted && has_fact)
        Vuppeteer::say("Notice: New fact #{s}#{k} already set...", :prep)
        self._set_as(:alts, k, @facts[k], source)
      else
        @facts[k] = v
      end
    end
  end

  def self._set_as(type, key, value, source = nil)
    @facts[@meta_facets[type][0]] = {} if !@facts.has_key?(@meta_facets[type][0])
    @facts[@meta_facets[type][0]][source] = {} if !source.nil? && !@facts[@meta_facets[type][0]].has_key?(source)
    @facts[@meta_facets[type][0]][source.nil? ? key : source] = source.nil? ? value : {key => value}
  end

  def self._filter(facts, filtered)
    filtered.each do |f|
      if facts.has_key?(f)
        why = @option_only_facts.include?(f) ? 'option_only_fact' : nil
        why = @local_only_facts.include?(f) ? 'local_only_fact' : nil if why.nil?
        why = @developer_facts.include?(f) ? 'developer_only_fact' : 'filtered_fact' if why.nil?
        skipped = "Warning: fact #{f} skipped because it is a #{why}"
        solution = why != 'filtered_fact' ? "pass this value from the Vagrantfile" : ''
        dev_fact = @developer_facts.include?(f) ? ' either developer facts or' : ''
        local_fact_options = " , or move it to#{dev_fact} #{FileManager::localize_token}.yaml..."
        solution = "#{solution}#{local_fact_options}" if solution != '' && !@option_only_facts.include?(f)
        Vuppeteer::say("#{skipped}, #{solution}", :prep)
        self::_set_as(:rdtd, f, facts[f])
        facts.delete(f) 
      end
    end
    facts
  end

  def self._instance_facts() #TODO filter instance facts?
    instance_file = Vuppeteer::instance()
    return if !instance_file.is_a?(String) || !File.exist?(instance_file)
    Vuppeteer::report('facts', '_main', 'instance')
    i_facts = FileManager::load_fact_yaml(instance_file, false)
    if (i_facts)
      @instance_facts = i_facts.keys()
      self._set(i_facts, 'instance')
    else
      Vuppeteer::say('Notice: no instance facts loaded (file was empty or invalid)', :prep)
    end
    return i_facts
  end

  def self._local_facts()
    local_file = "#{Mr::active_path}/#{FileManager::localize_token}.#{Mr::build}"
    parts = FileManager::facet_split(local_file)
    facet = parts.length > 1  && parts[1] != '' ? "::#{parts[1]}" : ''
    return if !File.exist?("#{parts[0]}.yaml") #NOTE this file is always optional, so don't even warn if it is missing
    Vuppeteer::report('facts', '_main', 'local')
    supplemental_facts = FileManager::load_fact_yaml("#{parts[0]}#{facet}", false)
    self._set(self._filter(supplemental_facts, @option_only_facts), 'local')
  end

  def self._project_facts()
    file_facts = FileManager::load_fact_yaml("#{Mr::active_path}/#{Mr::build}", false)
    return if !file_facts
    Vuppeteer::report('facts', '_main', 'project')
    filters = @local_only_facts + @developer_facts + @option_only_facts
    self._set(self._filter(file_facts, filters), 'project')
  end

  def self._developer_facts()
    parts = FileManager::facet_split("#{File.expand_path(Mr::developer_facts)}")
    facet = parts.length > 1 && parts[1] != '' ? "::#{parts[1]}" : ''
    extra = ": #{parts[0]}.yaml"
    can_read = FileManager::may?(:read, "#{parts[0]}.yaml")
    Vuppeteer::shutdown("Path for developer_facts outside of writable path#{extra}") if !can_read
    user_facts = FileManager::load_fact_yaml("#{parts[0]}#{facet}", false)
    return if !user_facts
    Vuppeteer::report('facts', '_main', '~developer')
    self._set(self._filter(user_facts, @local_only_facts + @option_only_facts), '~developer')
    if (@facts.include?('developer_sensitive'))
      s = MrUtils::enforce_enumerable(@facts['developer_sensitive'])
      s.each() do |v|
        Vuppeteer::mark_sensitive(@facts[v]) if @facts.include?(v)
      end
    end
  end

  def self._stack_facts()
    Vuppeteer::say("Loading stack puppet facts:", :prep)
    fact_sources = Vuppeteer::get_stack(:fact)
    fact_sources.each do |f|
      self._handle(f)
    end
    Vuppeteer::say(Vuppeteer::report('stack_facts'), :prep)
  end

  def self._validate_requirements()
    #Vuppeteer::trace(@requirements, @facts)
    begin
      errors = VuppeteerUtils::verify(@requirements, @facts)
    rescue => e
      Vuppeteer::shutdown(e.is_a?(String) ? e : e.to_s, e.is_a?(String) ? 3 : -3)
    end
    #Vuppeteer::trace(errors) if errors.length > 0
    error_label = errors.length > 2 ? 'validation errors' : 'valication error'
    additional = errors.length > 1 ? " (+#{errors.length - 1} more #{error_label})" : ''
    Vuppeteer::shutdown(Vuppeteer::enabled?(:verbose) ? errors : (errors[0] + additional)) if errors.length > 0
    ElManager::validate_vms(@facts)
  end

  def self._handle(s)
    blocked_facts = @option_only_facts + @local_only_facts + @developer_facts 
    path = Mr::active_path()
    fact_path = FileManager::path(:fact, "#{s}.yaml")
    fact_file = "#{fact_path}/#{s}.yaml"
    external = Vuppeteer::external? && fact_file == FileManager::path(:external, 'facts', "#{s}.yaml")
    global = fact_file == FileManager::path(:global, 'facts', "#{s}.yaml")
    local = fact_file == FileManager::path(:local, 'facts', "#{s}.yaml")
    type = external ? 'external' : (global ? 'global' : (local ? 'local' : 'project'))
    if (File.file?(fact_file) && File.readable?(fact_file))
      new_facts = FileManager::load_fact_yaml(fact_file, false)
      if new_facts.nil?
        Vuppeteer::report('stack_facts', s, "invalid.#{type}")
        return
      end
      self._set(new_facts, "#{s}.yaml") #TODO #1.1.0 handle stack merge flags before passing?
    else
      type = 'absent'
    end
    Vuppeteer::report('stack_facts', s, type)
  end

end