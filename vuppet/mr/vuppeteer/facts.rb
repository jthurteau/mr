## 
# Manages Puppet Facts for Mr
#

module Facts
  extend self

  @facts = nil
  @root_facts = []
  @requirements = []
  @generate = {}

  @meta_facets = {
    rdtd: ['__rdtd__', 'Redacted'],
    block: ['__hblk__', 'Locked'],
    alts: ['__alts__', 'Duplicate'],
  }

  ##
  # facts that can only be defined in Vagrantfile options
  @option_only_facts = [
    'mr_path',
    'root_path',
    'allowed_read_path',
    'allowed_write_path',
    'localize_token',
    'override_token',
  ]

  ##
  # facts that can only be defined in Vagrantfile options or {localize_token}
  @local_only_facts = [
    'developer_facts_file',
    'load_developer_facts',
  ]

  ##
  # facts that can only be defined in Vagrantfile options or local fact files
  # local fact files include, in order of loading:
  # {localize_token}.facts and developer_facts_file (~/.mr/developer.yaml)
  @local_developer_facts = [
    'pref_license_ident',
    'git_developer','ghc_developer','ghe_developer',
    'ghc_pat',
    'ghe_pat','ghe_host',
    'rhsm_user','rhsm_pass','rhsm_org', 'rhsm_key', 'rhsm_host',
  ]


  ##
  # load the inital facts file, remove invalid keys, and merge it in with root_facts
  def self.init()
    if (@facts)
      Vuppeteer::report('facts', '_main', 'root')
    else
      @facts = {}
    end
    FileManager::path_ensure("#{Mr::active_path}/facts", FileManager::allow_dir_creation?)
    file_facts = FileManager::load_fact_yaml("#{Mr::active_path}/#{Mr::project}.yaml", false)
    if (file_facts) 
      Vuppeteer::report('facts', '_main', 'project')
      (@local_only_facts + @local_developer_facts + @option_only_facts).each do |f|
        if file_facts&.has_key?(f)
          why = @option_only_facts.include?(f) ? 'option_only_fact' : 'local_only_fact'  
          skipped = "Warning: fact #{f} skipped because it is a #{why}"
          solution = "pass this value from the Vagrantfile"
          dev_fact = @local_developer_facts.include?(f) ? ' either developer facts or' : ''
          local_fact_options = " , or move it to#{dev_fact} #{FileManager::localize_token}.yaml..."
          solution = "#{solution}#{local_fact_options}" if !@option_only_facts.include?(f)
          Vuppeteer::say("#{skipped}, #{solution}", 'prep')
          self::_set_as(:rdtd, f, file_facts[f])
          file_facts.delete(f) 
        end
      end
      file_facts.each do |f,v|
        self._set_fact(f,v)
      end
    end
    self._local_facts() if Vuppeteer::enabled?(:local)
    self._developer_facts() if Vuppeteer::enabled?(:developer)
  end

  def self.post_stack_init() #NOTE additional steps that have to happen after stack init
    self._stack_facts() if Vuppeteer::enabled?(:stack)
    Vuppeteer::say('','prep') #NOTE adds a formatted line
    self.ensure_facts(@generate)
    Vuppeteer::say('','prep')
    self._validate_requirements()
  end

  def self.facts()
    @facts.clone()
  end

  def self.instance()
    self._instance_facts() if Vuppeteer::enabled?(:instance)
  end

  def self.fact?(match)
    return @facts&.has_key?(match) if !match.is_a?(Array) && !MrUtils::traversable(match)
    begin
      MrUtils::search(match, @facts, true)
    rescue => e
      Vuppeteer::trace('fact? fail', __FILE__,__LINE__,match, @facts, e)
      return false
    end
    return true
  end

  def self.get(match, default = nil)
    result = MrUtils::search(match, @facts)
    #Vuppeteer::trace(result,@facts,match)
    return !result.nil? ? result : default
  end

  def self.roots(f)
    Vuppeteer::shutdown('Error: Cannot define root facts once any are set.', -1) if !@facts.nil?
    Vuppeteer::shutdown('Error: Non-hash passed as root facts.' -1) if !f.respond_to?(:to_h)
    @facts = f.to_h
    @root_facts = @facts.keys()
  end

  def self.asserts(f) #TODO support additional types of asserts (like in/include, not_nil, class etc.)
    Vuppeteer::shutdown('Error: Non-hash passed as asserts.', -1) if !f&.respond_to?(:to_h)
    f.each do |k, v|
      @requirements.push({k => v}) 
    end
  end

  def self.requirements(r = nil)
    if (r.class.is_a?(Hash))
      r.each do |k, v| 
        @requirements += [[k] + MrUtils::enforce_enumerable(v)]
      end
    elsif (r.class.is_a?(Array))
      r.each do |v|
        @requirements += [v]
      end
    elsif !r.nil?
      @requirements += [r]
    end
    @requirements
  end

  def self.set(f, merge = false)
    e = f.class.include?(Enumerable)
    Vuppeteer::shutdown('Error: Cannot redefine facts once set', -3) if !@facts.nil? && !merge
    Vuppeteer::shutdown('Error: Initial facts must be a hash', -3) if !e && !merge
    if (merge) 
      @facts = {} if !@facts
      if (!e)
        Vuppeteer::say('Notice: Additional facts not a hash, skipping...', 'prep')
      else
        f.each do |k, v|
          rooted = @root_facts.any? {|r| r == k }
          has_fact = @facts&.has_key?(k)
          if (!rooted && has_fact && merge.class == TrueClass)
            @facts['__orig__'] = {} if !@facts.has_key?('__orig__')
            @facts['__orig__'][k] = [] if @facts['__orig__'][k].nil?
            @facts['__orig__'][k].push(@facts[k])
          elsif (!rooted && has_fact)
            Vuppeteer::say("Notice: New fact #{k} not flagged for merge...", 'prep')
            next
          elsif (rooted && has_fact)
            Vuppeteer::say("Notice: New fact #{k} is already rooted and cannot be set...", 'prep')
            next
          end
          self._set_fact(k,v)
        end
      end
    elsif (@facts.nil?)
      @facts = f
    else
      Vuppeteer::say("Warning: New facts rejected, merge not requested and initial facts set.", 'prep')
    end
  end

  def self.register_generated(f)
    @generate = @generate.merge(f)
  end

  def self.ensure_facts(f) #TODO in general
    Vuppeteer::trace('ensure facts', f)
    missing = {}
    storable = []
    f.each do |k, c|
      if (!self.fact?(k))
        missing[k] = c
        storable.push(k) if VuppeteerUtils::storable?(c)
        Vuppeteer.say(["testing fact #{k}... missing"],["generating fact #{k}"], 'prep')
      else
        Vuppeteer.say("testing fact #{k}... provided", 'prep')
      end
    end
    new_facts = VuppeteerUtils::generate(missing)
    self.set(new_facts, :new)
    storable_new_facts = {}
    storable.each do |k|
      storable_new_facts[k] = new_facts[k]
    end
    Vuppeteer::update_instance(storable_new_facts, true) if storable_new_facts.length > 0
  end

#################################################################
  private
#################################################################

  def self._set_fact(k, v)
    if @root_facts.any? {|r| r == k }
      self._set_as(:block, k, v)
    else
      @facts[k] = v
    end
  end

  def self._set_as(type, key, value, source = nil)
    @facts[@meta_facets[type][0]] = {} if !@facts.has_key?(@meta_facets[type][0])
    @facts[@meta_facets[type][0]][source] = {} if !source.nil? && !@facts[@meta_facets[type][0]].has_key?(source)
    @facts[@meta_facets[type][0]][source.nil? ? key : source] = source.nil? ? value : {key => value}
  end

  def self._local_facts()
    path = "#{Mr::active_path}/#{FileManager::localize_token}.yaml"
    return nil if !File.exist?(path) #NOTE this file is always optional, so don't even warn if it is missing
    Vuppeteer::report('facts', '_main', 'local')
    supplemental_facts = FileManager::load_fact_yaml(path, false)
    if (supplemental_facts)
      self.set(supplemental_facts, true)
    else
      Vuppeteer::say('Notice: supplemental (local) facts file present, but invalid', 'prep')
    end
  end

  def self._developer_facts()
    path = File.expand_path(Mr::developer_facts)
    extra = ": #{path}"
    Vuppeteer::shutdown("Invalid path for developer_facts, outside of writable path#{extra}") if !FileManager::may?(:read, path)
    Vuppeteer::report('facts', '_main', '~developer')
    user_facts = FileManager::load_fact_yaml(path, false)
    if (user_facts)
      self.set(user_facts, true)
    else
      Vuppeteer::say('Notice: developer facts file present, but invalid', 'prep')
    end
  end

  def self._stack_facts()
    Vuppeteer::say("Loading stack puppet facts:", 'prep')
    fact_sources = Vuppeteer::get_stack()
    fact_sources.each do |f|
      next if f.include?('.') && !f.end_with?('.yaml') #NOTE old
      next if f.include?('/') && !f.start_with?('facts/') #NOTE new
      if (f.start_with?('facts/'))
        y = f[6..-1]
      else
        y = f.end_with?('.yaml') ? f[0..-6] : f
      end
      if y.end_with?('.hiera') #NOTE this is moving to /hiera
        PuppetManager::inform_hiera(y[0..-7])
        next
      else
        self._handle(y)
      end
    end
  end

  def self._instance_facts()
    instance_file = Vuppeteer::instance()
    return if !File.exist?(instance_file)
    Vuppeteer::report('facts', '_main', 'instance')
    i_facts = FileManager::load_fact_yaml(instance_file, false)
    if (i_facts)
      self.set(i_facts, true)
    else
      Vuppeteer::say('Notice: no instance facts loaded (file was empty or invalid)', 'prep')
    end
    return i_facts
  end

  def self._validate_requirements()
    Vuppeteer::trace(@requirements, @facts)
    begin
      errors = VuppeteerUtils::verify(@requirements, @facts)
    rescue => e
      Vuppeteer::shutdown(e.class == String ? e : e.to_s, e.class == String ? 3 : -3)
    end
    Vuppeteer::trace(errors) if errors.length > 0
    print("\n")
    error_label = errors.length > 2 ? 'validation errors' : 'valication error'
    additional = errors.length > 1 ? " (+#{errors.length - 1} more #{error_label})" : ''
    Vuppeteer::shutdown(Vuppeteer::enabled?(:verbose) ? errors : (errors[0] + additional)) if errors.length > 0
  end

  def self._handle(s)
    blocked_facts = @option_only_facts + @local_only_facts + @local_developer_facts 
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
        Vuppeteer::report('facts', s, "invlid.#{type}")
        return
      end
      new_facts.each do |k,v|
        if blocked_facts.include?(k)
          self._set_as(:block, k, v, "#{s}.yaml")
        elsif (@facts.has_key?(k)) 
          self._set_as(:alts, k, v, "#{s}.yaml")
        else
          self._set_fact(k, v)
        end
      end
    end
    Vuppeteer::report('facts', s, type)
  end

end