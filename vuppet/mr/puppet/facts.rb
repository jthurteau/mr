## 
# Manages Puppet Facts for Mr
#

module PuppetFacts
  extend self

  @facts = nil
  @root_facts = []
  @meta_facets = {
    rdtd: ['__rdtd__', 'Redacted'],
    block: ['__hblk__', 'Locked'],
    alts: ['__alts__', 'Duplicate'],
  }
  @requirements = []
  @requirement_types = [
    :boolean,
    :integer,
    :hash,
    :array,
    :enumerable,
    :in,
    :include,
    :string,
    :string_length,
    :string_complexity,
    :string_regex,
    :members
  ]

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

  @features = {
    local: true,
    global: true,
    developer: false,
    stack: true,
  }  

  @generate = {}

  #@derived = {}

  ##
  # load the inital facts file, remove invalid keys, and merge it in with root_facts
  def self.init()
    @facts = {} if !@facts
    path = Mr::active_path()
    project_fact_file = Mr::facts()
    FileManager::path_ensure(path + '/facts', FileManager::allow_dir_creation?)
    source_file = "#{path}/#{project_fact_file}.yaml"
    file_facts = FileManager::load_fact_yaml(source_file, false)
    Vuppeteer::report('facts', '_main', 'hard') if @facts
    if (file_facts && file_facts.class.include?(Enumerable)) 
      Vuppeteer::report('facts', '_main', 'internal')
      (@local_only_facts + @local_developer_facts + @option_only_facts).each do |f|
        if file_facts&.has_key?(f)
          why = @option_only_facts.include?(f) ? 'option_only_fact' : 'local_only_fact'  
          skipped = "Warning: fact #{f} skipped because it is a #{why}"
          solution = "pass this value from the Vagrantfile"
          can_be_in_dev_file = @local_developer_facts.include?(f) ? ' either developer facts or' : ''
          local_fact_options = " , or move it to#{can_be_in_dev_file} #{FileManager::localize_token}.yaml..."
          solution = "#{solution}#{local_fact_options}" if !@option_only_facts.include?(f)
          Puppeteer::say("#{skipped}, #{solution}", 'prep')
          self::_set_as(:rdtd, f, file_facts[f])
          file_facts.delete(f) 
        end
      end
      file_facts.each do |k,v|
        self._set_fact(k,v)
      end
    end
    self._supplemental_facts() if @features[:local]
    self._developer_facts() if @features[:developer]
  end

  def self.post_stack()
    self._stack_facts() if @features[:stack]
    # Puppeteer::say('','prep') #NOTE this adds a formatted line
    # self._instance_facts()
    # Puppeteer::say('','prep')
    ##TODO these are probably deprecated
    # @overrides.each do |k,v| 
    #   Puppeteer::say("Override: #{k} set to #{v.to_s}", 'prep')
    #   self._set_fact(k, v)
    # end  
    ## TODO these are probably kept
    # if (self.fact?('required_facts'))
    #   self.add_requirements(self.get('required_facts'))
    # end
    # self._derived_facts()
    # self.ensure_facts(@generate)
    # #required = Puppeteer::enforce_enumerable(self.get('required_facts'))
    # @requirements.each do |r| #TODO add info about what requires it
    #   r_string = (r.is_a? Array) ? r.join(':') : r
    #   Puppeteer::shutdown("Error: Missing required fact #{r_string}") if !self.fact?(r)
    # end

    #self._validate()
  end

  def self.facts()
    @facts.clone()
  end

  def self.fact?(match)
    return @facts&.has_key?(match) if !match.is_a?(Array) && !MrUtils::traversable(match)
    begin
      MrUtils::search(match, @facts, true)
    rescue => e
      print(['fact? fail', __FILE__,__LINE__,match, @facts, e].to_e)
      return false
    end
    return true
  end

  def self.get(match, default = nil)
    result = MrUtils::search(match, @facts)
    #print([__FILE__,__LINE__,result,@facts,match].to_s)
    return !result.nil? ? result : default
  end

  def self.set_root_facts(f)
    Puppeteer::shutdown('Error: Cannot define root facts once any are set.', -1) if !@facts.nil?
    Puppeteer::shutdown('Error: Non-hash passed as root facts.' -1) if !f.respond_to?(:to_h)
    @facts = f.to_h
    @root_facts = @facts.keys()
  end

  def self.set_asserts(f) #TODO support additional types of asserts (like in/include, not_nil, class etc.)
    Puppeteer::shutdown('Error: Non-hash passed as asserts.', -1) if !f&.respond_to?(:to_h)
    f.each do |k, v|
      @requirements.push({k => v}) 
    end
  end

  def self.add_requirements(r)
    if (r.class.is_a?(Hash))
      r.each do |k, v| 
        @requirements += [[k] + MrUtils::enforce_enumerable(v)]
      end
    elsif (r.class.is_a?(Array))
      r.each do |v|
        @requirements += [v]
      end
    else
      @requirements += [r]
    end
  end

  def self.requirements()
    return @requirements
  end

  def self.set_facts(f, merge = false)
    e = f.class.include?(Enumerable)
    Puppeteer::shutdown('Error: Cannot redefine facts once set') if !@facts.nil? && !merge
    Puppeteer::shutdown('Error: Initial facts must be a hash') if !e && !merge
    if (merge) 
      @facts = {} if !@facts
      if (!e)
        Puppeteer::say('Notice: Additional facts not a hash, skipping...', 'prep')
      else
        f.each do |k, v|
          rooted = @root_facts.any? {|r| r == k }
          has_fact = @facts&.has_key?(k)
          if (!rooted && has_fact && merge.class == TrueClass)
            @facts['__orig__'] = {} if !@facts.has_key?('__orig__')
            @facts['__orig__'][k] = [] if @facts['__orig__'][k].nil?
            @facts['__orig__'][k].push(@facts[k])
          elsif (!rooted && has_fact)
            Puppeteer::say("Notice: New fact #{k} not flagged for merge...", 'prep')
            next
          elsif (rooted && has_fact)
            Puppeteer::say("Notice: New fact #{k} is already rooted and cannot be set...", 'prep')
            next
          end
          self._set_fact(k,v)
        end
      end
    elsif (@facts.nil?)
      @facts = f
    else
      Puppeteer::say("Warning: New facts rejected, merge not requested and initial facts set.", 'prep')
    end
  end

  def self.register_generated(f)
    @generate = @generate.merge(f)
  end

  def self.ensure_facts(f)
    missing = {}
    f.each do |k,c|
      if (!self.fact?(k))
        missing[k] = c
        Puppeteer.say("generating fact #{k}", 'prep')
      else
        Puppeteer.say("testing fact #{k}...provided", 'prep')
      end
    end
    new_facts = Puppeteer::generate(:random, missing)
    self.set_facts(new_facts, :new)
    path = Mr::active_path()
    localize_token = FileManager::localize_token()
    instance_file = "#{path}/#{localize_token}.instance.yaml"
    facts = FileManager::load_fact_yaml(instance_file, false) || {}
    any = false
    new_facts.each do |k,v|
      if (!facts.has_key?(v))
        facts[k] = v
        any = true
      else
        Puppeteer::say("Not setting generated fact #{k}, already present in instance facts...", 'prep')
      end
    end
    if any
      FileManager::save_yaml(instance_file, facts)
    end
  end

  # def self.set_derived(facts)
  #   @derived = facts
  # end

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

  def self._supplemental_facts()
    localize_token = FileManager::localize_token()
    path = Mr::active_path()
    supplemental_file = "#{path}/#{localize_token}.yaml"
    return nil if !File.exist?(supplemental_file)
    Puppeteer::report('facts', '_main', 'local')
    supplemental_facts = FileManager::load_fact_yaml(supplemental_file, false)
    if (supplemental_facts.class.include?(Enumerable))
      self.set_facts(supplemental_facts, true)
    else
      Puppeteer::say('Notice: supplemental (local) facts file present, but invalid', 'prep')
    end
  end

  def self._developer_facts()
    path = File.expand_path(@user_facts_file)
    return nil if !File.exist?(path)
    Vuppeteer::report('facts', '~user', 'present')
    user_facts = FileManager::load_fact_yaml(path, false)
    if (user_facts.class.include?(Enumerable))
      self.set_facts(user_facts, true)
    else
      Vuppeteer::say('Notice: developer facts file present, but invalid', 'prep')
    end
  end

  def self._stack_facts()
    Vuppeteer::say("Loading stack puppet facts:", 'prep')
    fact_sources = PuppetStack::get()
    fact_sources.each do |f|
      next if f.include?('.') && !f.end_with?('.yaml')
      y = f.end_with?('.yaml') ? f[0..-6] : f
      if y.end_with?('.hiera')
        PuppetHiera::handle(y[0..-7])
        next
      else
        self._handle(y)
      end
    end
  end

  # def self._instance_facts()
  #   path = Mr::active_path()
  #   localize_token = FileManager::localize_token()
  #   instance_file = "#{path}/#{localize_token}.instance.yaml"
  #   return Puppeteer::report('facts', 'instance', 'absent') if !File.exist?(instance_file)
  #   Puppeteer::report('facts', 'instance', 'present')
  #   i_facts = FileManager::load_fact_yaml(instance_file, false)
  #   if (i_facts.class.include?(Enumerable))
  #     @facts = {} if !@facts
  #     self.set_facts(i_facts, true)
  #   else
  #     Puppeteer::say('Notice: no instance facts loaded (file was empty or invalid)', 'prep')
  #   end
  # end

  # def self._derived_facts()
  #   @derived.each() do |d,f|
  #     if (self.fact?(f) && !self.fact?(d))
  #       @facts[d] = @facts[f]
  #       Puppeteer::say("Setting derived fact #{d} from #{f}", 'prep')
  #     elsif (!self.fact?(f))
  #       Puppeteer::say("Cannot set derived fact #{d}, #{f} not set", 'prep')
  #     else
  #       Puppeteer::say("Skipping derived fact #{d}, already set", 'prep')
  #     end
  #   end
  # end

  def self._validate_requirements()
    existing = {}
    @requirements.each do |r|
      if r.class.include?(Hash)
        r.each do |k, v|
          Puppeteer::shutdown("Error: duplicate conflicting assert for #{k}.") if existing.include?(k) and existing[k] != v
          existing += {k => v}
          Puppeteer::shutdown("Error: missing value for #{k}: required:#{v}.") if !@facts.include?(k)
          Puppeteer::shutdown("Error: incorrect value for #{k}: required:#{v}, found:#{}.") if @facts[k] != v
        end
      else
        Puppeteer::shutdown("Error: missing required value for #{r}.") if !@facts.include?(r) or @facts[r].nil?
      end
    end
  end

  def self._handle(s)
    blocked_facts = @option_only_facts + @local_only_facts + @local_developer_facts 
    path = Mr::active_path()
    fact_path = FilePaths::fact("#{s}.yaml")
    fact_file = "#{fact_path}/#{s}.yaml"
    #NOTE this is still from a time when the concept of external and global were muddled.
    #for now it will report "external" for both cases  
    external = Vuppeteer::external? && fact_file == FilePaths::external("#{s}.yaml",'facts')
    global = fact_file == FilePaths::global("#{s}.yaml",'facts')
    local = fact_file == FilePaths::local("#{s}.yaml",'facts')
    type = nil
    if (File.file?(fact_file) && File.readable?(fact_file))
      new_facts = FileManager::load_fact_yaml(fact_file, false)
      #TODO type nil if not Enumerable
      new_facts.each do |k,v|
        if blocked_facts.include?(k)
          self._set_as(:block, k, v, "#{s}.yaml")
        elsif (@facts.has_key?(k)) 
          self._set_as(:alts, k, v, "#{s}.yaml")
        else
          self._set_fact(k, v)
        end
      end
      if (!new_facts.nil?) 
        type = external ? 'external' : (global ? 'global' : (local ? 'local' : 'project'))
      end
    end
    Vuppeteer::report('facts', s, type)
  end

end