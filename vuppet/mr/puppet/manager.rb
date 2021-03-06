## 
# Manages Puppet Provisioning for Mr
#

module PuppetManager
  extend self

  require 'date'

  require_relative 'manifests'
  require_relative 'modules'
  require_relative 'hiera'

  @conf_source = ['puppet','::puppet'][0]
  @conf = nil

  @guest_path = 'vuppet'
  @guest_root = {default: '/vagrant', null: '/vagrant'}
  @version = {default: '6'}
  @groups = {}
  @opt = {}

  def self.init()
    @conf = Vuppeteer::load_facts(@conf_source, 'Notice:(Puppet Configuration)')
    if @conf
      @guest_path = @conf['guest_path'] if @conf['guest_path']
      if !ElManager::is_it?()
        @version[:default] = '7'
        Vuppeteer::say('PuppetManager: Switching to Puppet 7 which is the only version viable for Fedora', :prep) 
      else
        @version[:default] = @conf['default_version'] if @conf['default_version']
      end
      ['verbose', 'debug', 'output', 'log_format'].each do |o|
        @opt[o] = @conf[o] if @conf.has_key?(o)
      end
      mv = @conf.has_key?('module_versions') && @conf['module_versions'].is_a?(Hash)
      Modules::set_versions(@conf['module_versions']) if mv
      if (@conf['derived_facts'])
        if (@conf['derived_facts'].is_a?(Hash)) 
          @conf['derived_facts'].each() do |f, m|
            #Vuppeteer::trace('puppet derived', f, m)
            Vuppeteer::ensure_facts({f => {method: :derived, source: m}})
          end
        else
          Vuppeteer::say('Warning: Derived Facts configured for Puppet was not a Hash', :prep)
        end
      end
    else
      @conf = {}
      Vuppeteer::say("Notice: No puppet config provided (default version/options etc. are in place)", :prep)
    end
    Vuppeteer.disable(:puppet) if Vuppeteer::fact?('bypass_puppet')
    Modules::init(Vuppeteer::get_fact('puppet_modules'))
    Manifests::init()
    Hiera::init("#{@guest_root[:default]}/#{@guest_path}") if (Vuppeteer::enabled?(:hiera)) #TODO this has to be handled per VM too...
  end

  def self.apply(vm_names = :all, options = nil)
    run_options = self::_setup(options)
    vms = Vuppeteer::resolve(vm_names)
    #Vuppeteer::trace(vm_names, vms)
    vms.each() do |v|
      self._apply(run_options, v)
    end
  end

  def self.guest_path(p = '', v = nil)
    #guest_path(@module_shared_path, group)
    p = "/#{p}" if p != ''
    #Vuppeteer::trace('guest_path', p, v, "#{self.guest_root(v)}/#{@guest_path}#{p}")
    return "#{self.guest_root(v)}/#{@guest_path}#{p}"
  end

  def self.guest_root(vm_name = nil)
    return vm_name && @guest_root.has_key?(vm_name) ? @guest_root[vm_name] : @guest_root[:default]
  end

  def self.translate_guest_commands(commands)
    command_string = ''
    commands.each do |c|
      if (c.is_a?(Hash)) 
        command_string += "cd #{c.dig(:path)}" if c.has_key?(:path)
        command = c.dig(:cmd)
        command_string += "#{command}\n" if command
        #TODO support :say directive
        #TODO support returning to original :path
      else
        command_string += "#{c}\n"
      end
    end
    command_string
  end

  def self.version(w = nil)
    #Vuppeteer::trace('looking up puppet version for', w, @version)
    @version[w.nil? || !@version.has_key?(w) ? :default : w]
  end

  #################################################################
  # gateway methods
  #################################################################

  def self.set_manifest(v)
    Manifests::set_output_file(v)
  end

  def self.inform_hiera(s)
    Hiera::handle(s)
  end

  def self.pre_puppet()
    Manifests::generate()
    Vuppeteer::say(Vuppeteer::report('stack_manifest'), :prep)
    Hiera::generate()
    Vuppeteer::say(Vuppeteer::report('stack_hiera'), :prep)
  end

  def self.get_host_commands(which)
    case which
    when 'pre_puppet'
      Modules::get_commands(['local_install'])
    end
  end

#################################################################
  private
#################################################################

  def self._setup(options = nil)
      o = !options.nil? ? options : @opt
      ##came from Mr puppetize
      v = !o['verbose'].nil? && o['verbose'] #Vuppeteer::get_fact('puppet_verbose', false)
      d = !o['debug'].nil? && o['debug'] #Vuppeteer::get_fact('puppet_debug', false)
      o['out_options'] = (v ? '--verbose ' : '') + (d ? '--debug ' : '')
      o['out_log_to'] = !o['output'].nil? ? o['output'] : 'console' #Vuppeteer::get_fact('puppet_output', 'console')
      logtime = DateTime.now.strftime('%Y-%m-%d-%H-%M-%S')
      if ('file' == o['out_log_to'])
        temp_path = Vuppeteer::temp_path()
        local_log_path = "#{Mr::active_path()}/#{temp_path}logs"
        remote_log_path = "#{@file_path}/#{temp_path}logs"
        FileManager::path_ensure(local_log_path, true)
        log_format = !o['log_format'].nil? ? o['log_format'] : ''
        o['out_log_to'] = "#{remote_log_path}/puppet-provision-#{logtime}.log#{log_format}"
      end
      o
  end

  def self._apply(options, vm_name)
    vms = VagrantManager::get_vm_configs(vm_name)
    if (vms && vms.has_key?(vm_name))
      vm = vms[vm_name]
    else
      Vuppeteer::shutdown('Attempting to puppet apply to an undefined vm')
    end
    run_options = self._setup(options.nil? ? @opt : options)
    when_enabled = Vuppeteer::enabled?(:puppet) && true ? 'once' : 'never' #TODO detect puppet_bypass on individual VMs
    guest_root = @guest_root.has_key?(vm_name) ? @guest_root[vm_name] : @guest_root[:default]
    puppet_group = @groups.has_key?(vm_name) ? @groups[vm_name] : nil
    puppet_group = @version.has_key?(vm_name) ? @version[vm_name] : @version[:default] if !puppet_group
    #TODO figure out which vm in a multi-vm situation from options or additional param
    #CollectionManager::provision(VagrantManager::config()) #TODO why is this called twice? (also in _register)
    VagrantManager::host_pre_puppet_triggers()

    Modules::processCommands(puppet_group)
    prep_command_string = self.translate_guest_commands(Modules::get_commands(['status', 'install', 'additional']))
    sync_command_string = self.translate_guest_commands(Modules::get_commands(['dev_sync']))
    reset_command_string = self.translate_guest_commands(Modules::get_commands(['remove']))
    module_path = "#{Modules::guest_path()}/*"
    hard_reset_command_string = "rm -Rf #{module_path}"
    install_puppet_string = ElManager::puppet_install_script(vm_name)

    vm.provision 'puppet-reset', type: :shell, run: 'never' do |s|
      s.inline = "#{reset_command_string}"
    end

    vm.provision 'puppet-hard-reset', type: :shell, run: 'never' do |s|
      s.inline = "#{hard_reset_command_string}"
    end

    vm.provision 'puppet-prep', type: :shell do |s|
      s.inline = "#{install_puppet_string}\n#{prep_command_string}"
    end
    #TODO push this info VagrantManager => ElManager
    # fix_snippet = '8' == RhelManager::el_version() ? ("\n" + FileManager::bash('rhel8_puppet_fix') + "\n") : ''
    # #TODO, it's an ERB fragment, so that can now be done inline with ERB
    # rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm #an older version of 5?

    vm.provision 'puppet-sync', type: :shell , run: 'never' do |s|
      s.inline = sync_command_string
    end

    opt_notice = "\"#{run_options['out_options']} --logdest #{run_options['out_log_to']}\""
    vm_notice = "(VM #{vm_name}): Puppet options #{opt_notice}"
    Vuppeteer::say("Notice #{vm_notice}", :prep) if ('console' != run_options['out_log_to'])

    vm_facts = {
      'vagrant_root' => @guest_root,
      'guest_path' => @guest_path,
    }
    puppet_facts = Vuppeteer::facts().merge!(vm_facts) #TODO make a facter filter method?
    if (!Vuppeteer::enabled?(:puppet))
      Vuppeteer::say("Notice: Bypassing main Puppet provisioning", :prep)
    else
      vm.provision 'puppet', type: :puppet, run: when_enabled do |puppet|
        puppet.manifests_path = Manifests::path()
        puppet.manifest_file = Manifests::file()
        puppet.options = "#{run_options['out_options']} --logdest #{run_options['out_log_to']}"
        puppet.facter = puppet_facts 
        puppet.hiera_config_path = Hiera::config_path() if Vuppeteer::enabled?(:hiera) 
      end
      #TODO ^there may be an Mr or Vagrant/Puppet bug where Vagrant decides to destroy the VM when hiera is misconfigured and the specified file is missing...
    end

    vm.provision 'puppet-debug', type: :puppet, run: :never do |puppet|
      puppet.manifests_path = Manifests::path()
      puppet.manifest_file = Manifests::file()
      puppet.options = "--verbose --debug --write-catalog-summary --logdest #{run_options['out_log_to']}"
      puppet.facter = puppet_facts
      puppet.hiera_config_path = Hiera::config_path() if Vuppeteer::enabled?(:hiera)
    end
    #TODO ^there may be an Mr or Vagrant/Puppet bug where Vagrant decides to destroy the VM when hiera is misconfigured and the specified file is missing...
  end

end