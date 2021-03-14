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
  #TODO #1.1.0 see also sendfile vbox bug https://www.vagrantup.com/docs/synced-folders/virtualbox

  require_relative 'mr/utils'
  require_relative 'mr/file'
  require_relative 'mr/vuppeteer'
  require_relative 'mr/vagrant'
  require_relative 'mr/el'
  require_relative 'mr/puppet'

  ##
  # where mr runs from and aquires global(for intneral)/external recipes
  # for an "internal" mr project build, my_path and active_path are the same
  @my_path = File.dirname(__FILE__)

  ##
  # active_path is where mr builds and aquires local/project recipes
  # for an "external" mr project build, my_path and active_path are the different
  @active_path = 'vuppet'

  ##
  # indicates if everything that needs to happen before ::puppet_apply has happened
  @prepped = nil

  ##
  # the yaml file to use for mr, vuppet, build configuration
  # other yaml sources (puppet, vagrant, etc) can be a separate file, or '::x' to map to 'x' in build_facts_file
  @build_facts_file = 'vuppeteer'

  ##
  # a yaml file to use for local preferences if load_developer_facts is true
  # this may be set in options from the Vagrantfile or the local-dev.vuppeteer.yaml 
  @developer_facts_file = '~/.mr/developer'

  @once_warning = 'Warning: Mr::vagrant can only be called once, second entry detected'
  @bypass_message = 'Notice: Mr is DISABLED, normal provisioning and triggers bypassed'

  ##
  # Performs all of the setup on the provided vagrant config up to the puppet-prep stage
  # vagrant is vagrant config referece
  # options may be a hash, string, or nil
  # nil has the same effect as an empty hash (default options)
  # if a string is provided it is mapped to a Hash, {assert: {'project' => [string]}}
  def self.vagrant(vagrant, options = {})
    if !@prepped.nil?
      Vuppeteer::say(@once_warning)
      Vuppeteer::trace('Second entry at:')
      return
    end
    self._config(options)
    FileManager::init(File.dirname(MrUtils::caller_file(caller)))
    Vuppeteer::init(@active_path == @my_path ? nil : @my_path)
    ElManager::init()
    PuppetManager::init()
    VagrantManager::init(vagrant)
    @prepped = false
    Vuppeteer::shutdown('TEST: shutdown before start', -2)
    Vuppeteer::start()
    return Vuppeteer::say(@bypass_message) if !Vuppeteer::enabled?(:mr)
    ElManager::setup()
    VagrantManager::register_triggers!()
    Vuppeteer::build(ElManager::vms(:active))
  end 

  ##
  # Ensures prep steps have been applied and then sets up the puppet_apply provisioner
  def self.puppet_apply()
    return if !Vuppeteer::enabled?(:mr)
    if (!@prepped)
      Vuppeteer::shutdown('Error: attempting to manage puppet before initialization') if @prepped.nil?
      Vuppeteer::prep()
      @prepped = true
    end
    PuppetManager::apply()
  end

  ##
  # Registers a provisioner
  def self.add_provisioner(provisioner_name, config = nil, props = nil)
    return VagrantManager::add_helpers([provisioner_name]) if config.nil?() || props.nil?()
    VagrantManager::config().vm.provision provisioner_name , MrUtils::sym_keys(config) do |p|
      props.each do |h, v|
        p.send(h + '=', v)
      end
    end
  end

  ##
  # returns the path (dirname) to this file (aka my_path), or translates a path provided.
  # translation converts from active_path to external vuppeteer path (my_path) when applicable 
  def self.path(to_sub = nil)
    return @my_path if !to_sub
    return to_sub.sub(@active_path, @my_path) if to_sub.start_with?(@active_path)
    return to_sub.sub('./puppet', @my_path) if to_sub.start_with?('./puppet/')
    return to_sub.sub('puppet', @my_path) if to_sub.start_with?('puppet/')
    return to_sub 
  end
  
  def self.enabled?
    return Vuppeteer::enabled?(:mr)
  end

  def self.active_path
    return @active_path
  end

  def self.build
    return @build_facts_file
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
    configured_active_path = @active_path
    roots = {}
    option_roots = {}
    if (config.class.include?(Enumerable))
      MrUtils::sym_keys(config).each do |k, v|
        case k
        when :mr_path
          configured_active_path = v
          roots['mr_path'] = v
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
        when :safe_mount
          roots['safe_mount'] = v
          Vuppeteer::say("Notice: Safe Mount option invoked, but it is not implemented yet", 'prep')
        when :facts
          if (v.class == String)
            @build_facts_file = (y.end_with?('.yaml') ? v[0..-4] : v)
            valid_build_file = FileManager::facet_split(v)[0].length > 0
            Vuppeteer::shutdown("Error: Invalid build facts file provided #{v}") if !valid_build_file
          elsif (v.respond_to?(:to_h))
            option_roots = v
          else
            Vuppeteer::shutdown("Error: Invalid facts option passed in configuration")
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
        when :load_instance_facts
          Vuppeteer::disable(:instance) if !v
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
        when :verbose
          roots['verbose'] = v
          Vuppeteer::enable(:verbose) if v
        when :debug
          roots['debug'] = v
          roots['verbose'] = v if v
          Vuppeteer::enable(:debug) if v
          Vuppeteer::enable(:verbose) if v
        else
          Vuppeteer::say("Notice: Unrecognized configuration option: #{k}", 'prep')
        end
      end   
    elsif(!config.nil?)
      Vuppeteer::add_asserts({'project' => config.to_s})
    end
    option_roots.each do |r, v|
      if !roots.has_key?(r)
        roots[r] = v 
      else 
        Vuppeteer::say("Notice: Duplicate configuration options for #{r}" ,'prep')
      end
    end
    Vuppeteer::root(roots)
    @active_path = File.absolute_path(configured_active_path)
  end
  
end