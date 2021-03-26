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

  require_relative 'vagrant/manager'
  require_relative 'el/manager'
  require_relative 'puppet/manager'

  ##
  # indicates ::init has alread been called
  @initialized = false

  ##
  # indicates the path to external mr, if any
  @external_path = nil

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
    puppet: true,
    hiera: true,
  }

  def self.init(vagrant, path = nil)
    return if @initialized
    @external_path = path
    @initialized = true
    if (self.external?)
      Report::say("External Mr #{external_path} managing build.", :prep)
      @features[:installer] = true
    end
    instance_file = "#{Mr::active_path}/#{FileManager::localize_token}.instance.yaml"
    @features[:instance] = instance_file if @features[:instance] == true
    Facts::init()
    Host::init(Facts::instance())
    self._settings_check()
    Stack::init()
    Facts::post_stack_init()
    ElManager::init()
    PuppetManager::init() #TODO is there a reason this is before Vagrant?
    VagrantManager::init(vagrant)
  end

  def self.start()
    Facts::expose() if Facts::get('verbose_facts') || @features[:verbose]
    Report::say("Vuppeteer Features: #{@features.to_s}") if @features[:debug]
    Installer::prep() if self.external? && @features[:installer]
    Host::save(@features[:verbose])
    Repos::setup(Facts::get('project_repos'))
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

  def self.feature(o)
    @features[o] if @features.has_key?(o) 
  end

  def self.external?
    return !@external_path.nil?
  end

  def self.external_path
    return @external_path
  end

  def self.get(what, which = nil) #TODO trim down some delegations #TODO support getting vagrant configs

  end

  def self.add() #TODO trim down some delegations

  end

  def self.bow
    Host::save() if @instance_changed
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
    if (source.class == Array) 
      source.each() do |s|
        f = self.load_facts(s, flag)
        return f if f
      end
      return nil
    end
    begin
      source.start_with?(MrUtils::splitter) ? Facts::get(source[2..-1], nil, true) : FileManager::load_fact_yaml(source, flag)
    rescue => e
      VuppeteerUtils::meditate("#{e} for \"#{source}\"", flag, :prep)
      false
    end
  end

  def self.perform_host_commands(commands)
    return if commands.nil?
    current_dir = Dir.pwd()
    commands.each do |c|
      Host::command(c)
    end
    Dir.chdir(current_dir)
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

  def self.manifest(m)
    PuppetManager.set_manifest(m)
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

  def self.instance(key = nil)
    Host::instance(key)
  end

  def self.update_instance(k, v = nil?)
    Host::update(k,v)
  end

  def self.copy_unique(from, to) #TODO move this back into FileManager?
    Installer::copy_unique(from, to)
  end

  #################################################################
  # gateway methods
  #################################################################

  def self.shutdown(s, e = 1)
    Report::shutdown(s, e)
  end

  def self.say(output, trigger = :now, formatting = true)
    Report::say(output, trigger, formatting)
  end

  def self.trace(*s)
    c = MrUtils::caller_file(caller, :line)
    Report::say("TRACE #{c} #{s.to_s}", @features[:verbose] ? :now : :debug)
  end

  def self.deep_trace(*s)
    c = MrUtils::enforce_enumerable(caller)
    Report::say(["#{s.to_s}","TRACE - - - -"] + c + ["- - - - TRACE"], @features[:verbose] ? :now : :debug)
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

  def self.apply(which_vms, options)
    PuppetManager::apply(which_vms, options)
  end

  def self.add_provisioners(name, config, props, which = nil)
    #TODO support multi-vm
    VagrantManager::config().vm.provision name, MrUtils::sym_keys(config) do |p|
      props.each do |h, v|
        p.send(h + '=', v)
      end
    end
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
    VagrantManager::config_vms(which)
  end
  
  def self._settings_check()
    was = @features[:debug]
    @features[:debug] = Facts::get('debug', false)
    @features[:verbose] = (@features[:debug] || Facts::get('verbose', false))
    @features[:mr] = false if Facts::get('disabled')
    flush = (!was && @features[:debug]) ? '... flushing trigger buffers.' : ''
    Report::say("Notice: Debug Mode enabled#{flush}") if @features[:debug]
    VagrantManager::flush_trigger_buffer() if !was && @features[:debug]
  end

end