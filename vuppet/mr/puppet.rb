## 
# Manages Puppet Provisioning for Mr
#

module PuppetManager
  extend self

  require_relative 'puppet/manifests'
  require_relative 'puppet/modules'
  require_relative 'puppet/hiera'
  require_relative 'puppet/stack'

  @conf_source = ['puppet.yaml','::puppet'][0]
  @conf = nil
  @disabled = false
  @features = {
    puppet: true,
    hiera: true,
  }

  @file_path = '/vagrant/puppet'
  @version = ['6','5','3'][1]
  @opt = {}

  def self.init()
    self._init()
    PuppetStack::init()
    PuppetManifests::init()
  end

  def self.disabled?(what = :puppet)
    return !@features[what] if @features.include?(what)
    true
  end

  def self.disable(what = :puppet)
    @features[what] = false if @features.include?(what)
    Vuppeteer::say("Unsupported option for PuppetManager::disable #{what}") if !@features.include?(what)
  end

  def self.apply(options = nil)
    run_options = self::_setup(options)

    #CollectionManager::provision(VagrantManager::config()) #TODO why is this called twice? (also in _register)
    VagrantManager::host_pre_puppet_triggers()

    PuppetModules::processCommands(@version)
    prep_commands = PuppetModules::get_commands(['status', 'install', 'additional'])
    reset_commands = PuppetModules::get_commands(['remove'])
    sync_commands = PuppetModules::get_commands(['dev_sync'])
    prep_command_string = Vuppeteer::translate_guest_commands(prep_commands)
    sync_command_string = Vuppeteer::translate_guest_commands(sync_commands)
    reset_command_string = Vuppeteer::translate_guest_commands(reset_commands)

    VagrantManager::config().vm.provision 'puppet-reset', type: :shell, run: 'never' do |s|
      s.inline = "#{reset_command_string}"
    end

    #TODO push this info VagrantManager => ElManager
    # fix_snippet = '8' == RhelManager::el_version() ? ("\n" + ErBash::script('rhel8_puppet_fix') + "\n") : ''
    # #TODO, it's an ERB fragment, so that can now be done inline with ERB
    # VagrantManager::config().vm.provision 'puppet-prep', type: :shell do |s|
    #   s.inline = ErBash::script('puppet_prep', CollectionManager::credentials()) + fix_snippet + "\n#{prep_command_string}"
    #   # rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm #an older version of 5?
    # end

    VagrantManager::config().vm.provision 'puppet-sync', type: :shell , run: 'never' do |s|
      s.inline = sync_command_string
    end

    Puppeteer::say("Notice: Puppet options \"#{run_options['out_options']} --logdest #{run_options['log_to']}\"", 'prep') if ('console' != run_options['log_to'])

    if (self.disabled?)
      Puppeteer::say("Notice: Bypassing main Puppet provisioning", 'prep')
    else
      VagrantManager::config().vm.provision 'puppet' do |puppet|
        puppet.manifests_path = PuppetManifests::path()
        puppet.manifest_file = PuppetManifests::file()
        puppet.options = "#{run_options['out_options']} --logdest #{run_options['log_to']}"
        puppet.facter = Vuppeteer::facts() #TODO make a facter filter method?
        puppet.hiera_config_path = PuppetHiera::config_path() if !self.disabled?(:hiera)
      end
    end

    VagrantManager::config().vm.provision 'puppet-debug', type: :puppet, run: 'never' do |puppet|
      puppet.manifests_path = PuppetManifests::path()
      puppet.manifest_file = PuppetManifests::file()
      puppet.options = "--verbose --debug --write-catalog-summary --logdest #{run_options['log_to']}"
      puppet.facter = Vuppeteer::facts() #TODO make a facter filter method?
      puppet.hiera_config_path = PuppetHiera::config_path() if !self.disabled?(:hiera)
    end
  end

  def self.guest_puppet_path()
    return @file_path
  end

  def self.set_manifest(v)
    PuppetManifests::set_output_file(v)
  end

#################################################################
  private
#################################################################

  def self._init()
    if (@conf_source.start_with?('::'))
      @conf = Vuppeteer::get_fact(@conf_source[2..-1], {})
    else
      @conf = FileManager::load_fact_yaml(@conf_source, 'Puppet')
    end
    if @conf
      @file_path = @conf['files'] if @conf['files']
      @version = @conf['version'] if @conf['version']
      ['verbose', 'debug', 'output', 'catalog', 'log_format'].each do |o|
        @opt[o] = @conf[o] if @conf.has_key?(o)
      end
      m = @conf.has_key?['module_versions'] && @conf['module_versions'].class == Hash
      PuppetModules::set_versions(@conf['module_versions']) if m
      Vuppeteer::set_derived(@conf['derived_facts']) if @conf['derived_facts']
    else
      Vuppeteer::say("Notice: No puppet config provided (default version/options etc. are in place)", 'prep')
    end
    Vuppeteer::set_facts({'puppet_files' => @file_path}, true)
    PuppetModules::init(Vuppeteer::get_fact('puppet_modules'))
    PuppetHiera::init(@file_path) if (!self.disabled?(:hiera))
    local_stack = []
    local_stack.push('project_' + Vuppeteer::get_fact('project').to_s) if Vuppeteer::fact?('project') 
    local_stack.push('app_' + Vuppeteer::get_fact('app').to_s) if Vuppeteer::fact?('app') 
    local_stack.push('developer_' + Vuppeteer::get_fact('developer')) if Vuppeteer::fact?('developer')
    self.disable() if Vuppeteer::fact?('bypass_puppet')
    PuppetStack::add(local_stack, false)
    ElManager::init() #setup() used to be here (in mr.rb anyway)
  end

  def self._setup(options = nil)
      o = !options.nil? ? options : @opt
      ##came from Mr puppetize
      v = !o['verbose'].nil? && o['verbose'] #Vuppeteer::get_fact('puppet_verbose', false)
      d = !o['debug'].nil? && o['debug'] #Vuppeteer::get_fact('puppet_debug', false)
      c = !o['catalog'].nil? && o['catalog']
      o['out_options'] = (v ? '--verbose ' : '') + (d ? '--debug ' : '')
      o['out_options'] += '--write-catalog-summary ' if c
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

end