## 
# Base Interface MrRogers provides to provisioners
#

module Vuppeteer
  extend self

  require_relative 'vuppeteer/utils'
  require_relative 'vuppeteer/facts'
  require_relative 'vuppeteer/stack' 
  require_relative 'vuppeteer/host'
  require_relative 'vuppeteer/installer'
  require_relative 'vuppeteer/report'

  ##
  # indicates ::init has alread been called
  @initialized = false

  ##
  # indicates the path to external mr, if any
  @external_path = nil

  ##
  # values from the instance_facts at session start
  @instance = nil

  ##
  # indicates something changed the instance during this session
  @instance_changed = false

  # #   @timezone = 'America/New_York' #TODO   
  # #   @when_to_reregister = ['never', 'always'][0] 

  @features = {
    mr: true,
    verbose: false,
    debug: false,
    local: true,
    global: true,
    developer: false,
    stack: true,
    instance: true,
    installer: false,
    autofilter: true,
  }

  def self.init(path = nil)
    return if @initialized
    @external_path = path
    @initialized = true
    if (self.external?)
      self.say("External Mr #{external_path} managing build.", :prep)
      @features[:installer] = true
    end
    @features[:instance] = "#{Mr::active_path}/#{FileManager::localize_token}.instance.yaml" if @features[:instance] == true
    Facts::init()
    @instance = Facts::instance()
    was = @features[:debug]
    @features[:debug] = Facts::get('debug')
    @features[:mr] = false if Facts::get('disabled')
    @features[:verbose] = @features[:debug] || Facts::get('verbose')
    self.say('Notice: Debug Mode enabled' + (!was && @features[:debug] ? '... flushing trigger buffers.' : ''))
    VagrantManager::flush_trigger_buffer() if !was && @features[:debug]
    Stack::init()
    Facts::post_stack_init()
  end

  def self.start()
    self.expose_facts() if Facts::get('verbose_facts') || @features[:verbose]
    self.say("Vuppeteer Features: #{@features.to_s}") if @features[:debug]
    Installer::prep() if self.external? && @features[:installer]
    self.save_instance(true)
    FileManager::setup_repos(Facts::get('project_repos'))
  end

  def self.prep()
    ElManager::setup()
    VagrantManager::register_triggers!()
    Vuppeteer::_build(ElManager::catalog(:active))
    return true
  end

  def self.disable(o)
    @features[o] = false
  end
  
  def self.enable(o)
    @features[o] = true
  end

  def self.enabled?(o)
    @features.has_key?(o) && @features[o]
  end

  def self.external?
    return !@external_path.nil?
  end

  def self.external_path
    return @external_path
  end

  def self.instance(key = nil)
    return key.nil? ? @features[:instance] : (@instance && @instance.has_key?(key) ? @instance[key] : nil)
  end

  ##
  # updates the instance facts
  # if passed a key and value, it will "lazy_save" which may result in loss of data
  # if the current process fails
  # pass a hash and true to force immediate state changes
  def self.update_instance(k, v = nil?)
    #Vuppeteer::trace('updating instance', k, v)
    @instance = {} if @instance.nil? && (k.class == Hash || !v.nil?)
    if (k.class == Hash) 
      k.each() do |hk, hv|
        self.update_instance(hk, hv)
      end
      self.save_instance(true) if v
      return
    end
    if (!v.nil? && (!@instance.has_key?(k) || v != @instance[k]))
      #Vuppeteer::trace('updating add', k, v)
      @instance[k] = v
      Facts::promote(k, v)
      @instance_changed = true
    elsif (!@instance.nil? && @instance.has_key?(k) && v.nil?)
      #Vuppeteer::trace('updating removing', k)
      Facts::demote(k)
      @instance_changed = true
      @instance.delete(k)
    end
  end

  def self.save_instance(verbose = false)
    #Vuppeteer::trace('saving instance', @instance)
    return if @features[:instance].class != String || !@instance_changed
    saved = FileManager::save_yaml(@features[:instance], @instance)
    @instance_changed = false if @instance_changed && saved
    Vuppeteer::say('Notice: Updated the instance facts file') if saved && verbose
  end

  def self.expose_facts() #TODO gateway this to facts?
    self.say(Report::pop('facts'), :prep)
    self.say(
      [
        'Processed Facts:',
        MrUtils::inspect(Facts::facts(), true), 
        '----------------',
      ], :prep
    )
  end

  def self.trace(*s)
    c = MrUtils::caller_file(caller, :line)
    self.say("TRACE #{c} #{s.to_s}", @features[:verbose] ? :now : :debug)
  end

  def self.deep_trace(*s)
    c = MrUtils::enforce_enumerable(caller)
    self.say(["#{s.to_s}","TRACE - - - -"] + c + ["- - - - TRACE"], @features[:verbose] ? :now : :debug)
  end

  def self.bow
    self.save_instance() if @instance_changed
  end

  #################################################################
  # delegations
  #################################################################

  def self.report(facet, field = nil, prop = nil)
    if !field.nil? && !prop.nil?
      Report::push(facet, field, prop)
    else 
      Report::pop(facet)
    end
  end

  def self.root(f)
    Facts::roots(f)
  end

  def self.get_fact(f, default = nil)
    Facts::get(f, default)
  end

  def self.get_stack(options = nil)
    return Stack::get(options)
  end
  
  def self.facts(list = nil)
    Facts::facts()
  end

  def self.fact?(f)
    Facts::fact?(f)
  end

  def self.load_facts(source, flag = nil)
    begin
      source.start_with?(MrUtils::splitter) ? Facts::get(source[2..-1], nil, true) : FileManager::load_fact_yaml(source, flag)
    rescue => e
      VuppeteerUtils::meditate("#{e} for \"#{source}\"", flag, :prep)
    end
  end

  def self.import_files()
    return Facts::get('import', [])
  end

  def self.add_derived(d)
    if (d.class != Hash) 
      Report::say("Warning: invalid derived facts sent during Puppet initialization", :prep)
      return
    end
    Facts::register_generated(d)
  end

  def self.add_asserts(v)
    Facts::asserts(v)
  end

  def self.add_requirements(v)
    Facts::requirements(v)
  end

  def self.register_generated(v)
    Facts::register_generated(v)
  end

  def self.perform_host_commands(commands)
    return if commands.nil?
    current_dir = Dir.pwd()
    commands.each do |c|
      Host::command(c)
    end
    Dir.chdir(current_dir)
  end

  def self.get_vm(name)
    VagrantManager::get_vm(name)
  end

  def self.resolve(names = nil)
    ElManager::catalog(names)
  end

  def self.helpers(which = nil, h = nil)
    VagrantManager::setup_helpers(which, h)
  end

  #################################################################
  # gateway methods
  #################################################################

  def self.install_files()
    return Installer::install_files() if @features[:installer]
  end

  def self.global_install_files()
    return Installer::global_install_files() if @features[:installer]
  end

  def self.shutdown(s, e = 1)
    Report::shutdown(s, e)
  end

  def self.say(output, trigger = :now, formatting = true)
    Report::say(output, trigger, formatting)
  end

  def self.remember(output)
    Report::remember(output)
  end

  def self.pull_notices()
    Report::pull_notices()
  end

  def self.mark_sensitive(s)
    Report::mark_sensitive(s)
  end

  def self.filter_sensitive(s)
    Report::filter_sensitive(s)
  end

  def self.get_sensitive()
    Report::get_sensitive()
  end

  #################################################################
  private
  #################################################################

  def self._build(which)#which = nil)
    #which = [ElManager.catalog()] if which.nil?
    VagrantManager::init_plugins(which)
    VagrantManager::build(which) #TODO, handle multi vm situations
    #Vuppeteer::trace(which,VagrantManager::get_vm_configs(:all))
    ElManager::register(VagrantManager::get_vm_configs(:all))
    VagrantManager::config_vms(which) #TODO, handle multi vm situations
  end
  
end