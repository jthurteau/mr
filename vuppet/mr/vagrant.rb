## 
# Encapsulates Vagrant management for MrRogers
#

module VagrantManager
  extend self

  require_relative 'vagrant/triggers'
  require_relative 'vagrant/plugins'

  @vagrant = nil
  @version = nil
  @ruby_version = nil
  @setup = nil
  @conf_source = ['vagrant', '::vagrant'][0]
  @features = {
    vb_middleware: true,
    linked_clones: false
  }
  @vm_configs = {}

  def self.init(singleton)
      @vagrant = singleton
      @version = Vagrant::VERSION
      @ruby_version = RUBY_VERSION
      @setup = Vuppeteer::load_facts(@conf_source, 'Notice:(Vagrant Configuration)')
      @vagrant.config.vagrant.sensitive = Vuppeteer::get_sensitive() if Mr::enabled?
  end

  def self.get()
      @vagrant
  end

  def self.config_vm(vm = nil)
    Vuppeteer::shutdown("vm " + vm.to_s, -2)
    return if !Mr::enabled?
    vagrant_default_warning = "Notice: No vagrant config provided (so default network/shared etc. are in place)"
    Vuppeteer::say(vagrant_default_warning, 'prep') if !@setup
    self._vb_setup()
    if (self._linked_clone?(vm))
      # config.vm.provider 'virtualbox' do |v|
      #   v.linked_clone = true if Gem::Version.new(Vagrant::VERSION) >= Gem::Version.new('1.8.0')
      # end
    end

    if (vm.nil?)
      self._config(@vagrant.config.vm)
    else
      @vagrant.config.vm.define vm do |v|
        self._config(v.vm, vm)
      end
    end
  end

  def self.version()
    @version
  end

  def self.get()
    @vagrant
  end

  ##
  # sets up standard triggers for Mr
  def self.register_triggers!()
    Triggers::register!(@vagrant) if Mr::enabled?
  end

  def self.set_destroy_trigger(script)
    return if !Mr::enabled?
    @vagrant.trigger.before [:destroy] do |trigger|
      trigger.warn = 'Attempting to unregister this box before destroying...'
      trigger.run_remote = {
        inline: script
      }
    end
  end
  
  def self.host_pre_puppet_triggers()
    return if !Mr::enabled?
    @vagrant.trigger.before [:up, :provision, :reload, :resume] do |trigger|
      trigger.info = 'Checking, are Strings Attached?'
      trigger.ruby do |env, machine|
        PuppetManager::pre_puppet()
        Vuppeteer::perform_host_commands(PuppetManager::get_host_commands('pre_puppet'))
      end
    end
  end

  def self.store_say(s, t)
    if Triggers::triggered?(t)
      print s
    else
      Triggers::store_say(s,t)
    end
  end

  def self.halt_vb_guest()
    @prevent_vb_middleware = true
    Vuppeteer::say('Notice: VirtualBox Guest Additions Plugin Autoloading Disabled.', 'prep');
  end

  def self.halted_vb_guest?()
    @prevent_vb_middleware
  end

  def self.init_plugins(vm)
    Plugins::init()
  end

  def self.plugin_managing?(p)
    Plugins::managing?(p)
  end

  def self.plugin(p)
    Plugins::setup(p) if Mr::enabled?
  end

  def self.setup_helpers(v = nil, h = nil)
    Helpers::setup(v, h) if Mr::enabled?
  end

  def self.flush_trigger_buffer()
    Triggers::flush()
  end

  #################################################################
    private
  #################################################################

  def self._vb_setup()
    if (!@features[:vb_middleware])
      @vagrant.vbguest.auto_update = false
    end
  end

  def self._config(vm, label = nil)
    vm.box = ElManager::box(label)
    if (@setup.nil? || (!label.nil? && !@setup.include?(label)))
      vm_label = label.nil? ? 'vm' : "vm:#{label}" 
      Vuppeteer::say("Warning: could not configure vagrant #{vm_label} from facts")
      return
    end
    vm_setup = label.nil? ? @setup : @setup[label]
    ##
    # providers
    vm.provider 'virtualbox' do |vb|
      ##TODO we can probably streamline builds with linked clones
      #vb.linked_clone = true if Gem::Version.new(Vagrant::VERSION) >= Gem::Version.new('1.8.0')
      vb.gui = vm_setup && vm_setup.has_key?('gui') ? vm_setup['gui'] : false
      vb.memory = vm_setup && vm_setup.has_key('memory') ? vm_setup['memory'] : '1024'
    end

    if (vm_setup && vm_setup.class.include?(Enumerable))
      ##
      # config.vm.box_check_update = false
      # config.vm.guest manually set to :windows for windows guest
      # config.vm.communicator set to "winrm" for windows guest

      ##
      # new option? config.vm.hostname

      ##
      # forwarded ports
      network = vm_setup.has_key?('network') ? vm_setup['network'] : []
      network.each do |n|
        h = Vuppeteer::sym_keys(n[1])
        vm.network n[0], h 
      end

      ##
      # shared folders
      shared = vm_setup.has_key?('synced_folder') ? vm_setup['synced_folder'] : []
      shared.each do |s|
        h = Vuppeteer::sym_keys(s[2])
        #TODO warn if there is no explicit type:
        vm.synced_folder s[0], s[1], h 
      end

      #TODO make sure guest_path is set from facts when present
      #VagrantManager::config().vm.synced_folder '.', @guest_path, owner: 'vagrant', group: 'vagrant', type: 'virtualbox'
    end
  end

  def self._linked_clone?(vm)
    return false if !@features.has_key?(:linked_clones) 
    return @features[:linked_clones].class == TrueClass || (@features.respond_to?('include?') && @features.include?(vm))
  end

end