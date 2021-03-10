## 
# Helps Manage Evironment Replication for Puppetized Fedora based Vagrants, Primarily RHEL
# https://puppet.com/docs/puppet/5.5 https://puppet.com/docs/puppet/6.20
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/ 
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/ 
# https://www.linux.ncsu.edu/rhel-unc-system/
# https://www.vagrantup.com/docs/
#
# You do not need Ruby on the guest for this module.
# You should not need Ruby installed on the host, aside from the runtime Vagrant uses
# see ../Vagrantfile for how this module is used
#

module Mr
  extend self

  #HENEYDO
  #TODO see also sendfile vbox bug
  # https://www.vagrantup.com/docs/synced-folders/virtualbox

  require_relative 'mr/utils'
  require_relative 'mr/file'
  require_relative 'mr/vuppeteer'
  require_relative 'mr/vagrant'
  require_relative 'mr/el'
  require_relative 'mr/puppet'

  ##
  # where mr runs from and aquires global(for intneral)/external recipies
  # for an "internal" mr project build, my_path and active_path are the same
  @my_path = File.dirname(__FILE__)

  ##
  # active_path is where mr builds and aquires local/project recipies
  # for an "external" mr project build, my_path and active_path are the different
  @active_path = 'vuppet'

  ##
  # if mr is disabled it will load and parse configuration, but manage no provisioners
  # basic Vagrant operations should still be available (up, reload, halt, non-mr provisioning etc.)
  @disabled = false

  ##
  # indicates if everything that needs to happen before ::puppet_apply has happened
  @prepped = nil

  ##
  # the yaml file to use for mr, vuppet, project configuration
  # other yaml sources (puppet, vagrant, etc) can be a separate file, or '::x' to map to 'x' in project_fact_file
  @project_facts_file = 'project'

  ##
  # a yaml file to use for local preferences if load_developer_facts is true
  # this may be set in options from the Vagrantfile or the local-dev.project.yaml 
  @developer_facts_file = '~/.mr/developer.yaml'

  ##
  # Performs all of the setup on the provided vagrant config up to the puppet-prep stage
  # options may be a hash, string, or nil
  # nil has the same effect as an empty hash (default options)
  # if only a string is provided it is mapped to {assert: {'project' => [string]}}
  def self.vagrant(vagrant, options = {})
    self._config(options)
    self._init(vagrant, MrUtils::caller_file(caller))
    Vuppeteer::start()
    Vuppeteer::verify()
    Vuppeteer::shutdown('End of the Line for now', -1)
    if (!@disabled)
      ElManager::setup()# CollectionManager::request(Vuppeteer::get_fact('software_collection', RhelManager::sc))
      Vuppeteer::sync()
      VagrantManager::register_triggers!()
    else
      Vuppeteer::say('Notice: Mr is DISABLED, normal provisioning and triggers bypassed')
    end
    VagrantManager::init_plugins()
    VagrantManager::config_vm() #TODO, handle multi vm situations
    # x.each() do |a|
    #   #box_name = ElManager::name_gen()
    #   #infrastructure_name = ElManager::infra_gen()
    #   #delim = infrastructure_name != '' && !infrastructure_name.nil? ? '-' : ''
    #   #ElManager::is_it? ? ElManager::box() : @box_source
    #   b = "#{box_name}#{delim}#{infrastructure_name}".ljust(2, '0')
    #   VagrantManager::config_vm(b)
    # end
  end 

  ##
  # Ensures prep steps have been applied and then sets up the puppet_apply provisioner
  def self.puppet_apply(options = nil)
    Vuppeteer::shutdown('Not so fast....', -1)
    return nil if @disabled || PuppetManager::disabled?()
    self._prep()
    PuppetManager::apply()
  end

  ##
  # Registers a provisioner
  def self.add_provisioner(provisioner_name, config, props)
    #TODO accept helper_provisioners
    VagrantManager::config().vm.provision provisioner_name , MrUtils::sym_keys(config) do |p|
      props.each do |h, v|
        p.send(h + '=', v)
      end
    end
  end

  ##
  # returns the path (dirname) to this file (aka my_path), or translates a path provided.
  # translation converts from active_path to external puppeteer path (my_path) when applicable 
  def self.path(to_sub = nil)
    return @my_path if !to_sub
    return to_sub.sub(@active_path, @my_path) if to_sub.start_with?(@active_path)
    return to_sub.sub('./puppet', @my_path) if to_sub.start_with?('./puppet/')
    return to_sub.sub('puppet', @my_path) if to_sub.start_with?('puppet/')
    return to_sub 
  end
  
  def self.active_path
    return @active_path
  end

  def self.project
    return @project_facts_file
  end

  def self.developer_facts
    return @developer_facts_file
  end

  ##
  # this was the puppet_apply step in v0.x
  def self.puppetize(x = nil)
    Vuppeteer::shutdown('method ::puppetize is depreciated in v1.X, see ::puppet_apply for analogous functionality.', -3)
  end

  ##
  # This was a way to add some pre-built provisioners in v0.x
  def self.add_helpers(x = [], y = nil)
    Vuppeteer::shutdown('method ::add_helpers is depreciated in v1.X, see ::add_provisioner for analogous functionality.', -3)
  end

  ##
  # This was the "init" step in v0.x
  def self.box(x = nil, y = nil)
    Vuppeteer::shutdown('method ::box is depreciated in v1.X, see ::vagrant for analogous functionality.', -3)
  end

  #################################################################
    private
  #################################################################

  def self._config(config)
    Vuppeteer::shutdown('Error: attempting to re-configure Mr after initialization') if !@prepped.nil?
    configured_active_path = @active_path
    roots = {}
    option_roots = {}
    if (config.class.include?(Enumerable))
      MrUtils::sym_keys(config).each do |k, v|
        case k
        when :mr_path
          configured_active_path = v
          roots['mr_path']
        when :localize_token
          roots['localize_token'] = v
        when :override_token
          roots['override_token'] = v
        when :root_path
          roots['host_root_path'] = v
        when :allowed_read_path
          roots['host_allowed_read_path'] = v
        when :allowed_write_path
          roots['host_allowed_write_path'] = v
        when :facts
          if (v.class == String)
            @project_facts_file = (y.end_with?('.yaml') ? v[0..-4] : v)
          elsif (v.respond_to?(:to_h))
            option_roots = v
          else
            Vuppeteer::shutdown("Error: Invalid facts option passed in configuration", -3)
          end
        when :generated
          Vuppeteer::register_generated(v)
        when :assert
          Vuppeteer::add_asserts(v)
        when :require
          Vuppeteer::add_requirements(v)
        when :load_stack_facts
          Vuppeteer::disable(:stack) if !v
        when :load_local_facts
          Vuppeteer::disable(:local) if !v
        when :load_developer_facts
          Vuppeteer::enable(:developer) if v
          if (v.class == String)
            @developer_facts_file = v
          end
        when :target_manifest
          PuppetManager::set_manifest(v)
        when :stack
          roots['stack'] = v
        when :disable_hiera
          roots['hiera_disabled'] = v
          PuppetManager::disable(:hiera) if v
        else
          Vuppeteer::say("Unrecognized configuration option: #{k}", 'prep')
        end
      end   
    elsif(!config.nil?)
      Vuppeteer::add_asserts({'project' => config.to_s})
    end
    option_roots.each do |r, v|
      roots[r] = v if !roots.has_key?(r)
    end
    Vuppeteer::set_root_facts(roots)
    @active_path = File.absolute_path(configured_active_path)
  end

  def self._init(v, vagrant_file)
    return if !@prepped.nil?
    FileManager::init(File.dirname(vagrant_file))
    Vuppeteer::init(@active_path == @my_path ? nil : @my_path)
    @disabled = Vuppeteer::get_fact('disabled', false)
    PuppetManager::init()
    VagrantManager::init(v)
    @prepped = false
  end

  def self._prep()
    Vuppeteer::shutdown('Error: attempting to manage puppet before Mr is initialized') if @prepped.nil?
    return if @prepped
    self._path_setup()
    FileManager::global_ensure()
    #TODO, these can be pushed down
    Vuppeteer::set_facts({ 'vagrant_root': @guest_path}, true)
    ElManager::resgister(VagrantManager::config())
    VagrantManager::post_puppet()
    @prepped = true
  end
  
end