## 
# Encapsulates Vagrant management for Mr
#

module VagrantManager
  extend self

  require_relative 'triggers'
  require_relative 'plugins'
  require_relative 'helpers'

  @vagrant = nil
  @version = nil
  @ruby_version = nil
  @setup = {
    null: {
      network: [
        ['forwarded_port', {guest: 80, host: 8080, host_ip: '127.0.0.1'}],
      ],
      synced_folder: [
        ['.', :guest_root, owner: 'vagrant', group: 'vagrant', type: 'virtualbox'],
      ],
    }
  }
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
    @setup[:default] = Vuppeteer::load_facts(@conf_source, 'Notice:(Vagrant Configuration)')
    @setup[:default] = @setup[:null].clone if @setup[:default].nil?
    return if !Mr::enabled?
    Vuppeteer::say('')
    if (!@features[:vb_middleware] && Vagrant.has_plugin?('vbguest'))
      @vagrant.vbguest.auto_update = false
    end
    @vagrant.vagrant.sensitive = Vuppeteer::get_sensitive() 
    # if (self._linked_clone?(vm))
      # config.vm.provider 'virtualbox' do |v|
      #   v.linked_clone = true if Gem::Version.new(Vagrant::VERSION) >= Gem::Version.new('1.8.0')
      # end
    # end
  end

  def self.get(w = nil)
      return @vagrant.trigger if w == :trigger
      @vagrant
  end

  def self.get_vm(w = nil)
    return @vm_configs[@vm_configs.keys().first()] if w.nil? and @vm_configs.keys().length() > 0
    @vm_configs[w] if @vm_configs.has_key?(w)
    nil
end

  def self.get_vm_configs(names)
    return @vm_configs if names == :all
    results = {}
    names = MrUtils::enforce_enumerable(names)
    names.each() do |n|
      results[n] = @vm_configs[n] if @vm_configs.has_key?(n)
    end
    results
  end

  def self.build(vm = nil)
    return if !Mr::enabled?
    vagrant_default_warning = "Notice: No vagrant config provided (so default network/shared etc. are in place)"
    Vuppeteer::say(vagrant_default_warning, :prep) if !@setup
    vms = ElManager::catalog(vm)
    current_vm = vms.pop()
    multi_vm = false
    if (current_vm)
      #Vuppeteer::trace('build VMs', current_vm, vms)
      #@vagrant.vm.box = ElManager::box(:default) #NOTE this was a duplicate for a call in config_vms -> _config
      #TODO config.vm.box_download_options = {"limit-rate": "423K"}
      self._build(@vagrant.vm, current_vm)
      loop do
        @vagrant.vm.define current_vm do |c|
          self._build(c.vm, current_vm)
        end
        # #self._config(@vagrant.vm, current_vm)
        # @vagrant.vm.define current_vm do |c|
        #   Vuppeteer::trace('build VM', c)
        #   @vm_configs[current_vm] = c
        # end
        current_vm = vms.pop()
        #Vuppeteer::trace('additional VMs', current_vm)
        Vuppeteer::shutdown('temporarily blocking multi-vm', -2) if !multi_vm && !current_vm.nil?
        break if !multi_vm || current_vm.nil?
        Vuppeteer::trace('build VM', current_vm)
      end
    else
      Vuppeteer::shutdown('Error: No VMs to provision') if !current_vm #vms.length() < 1
    end
    @vm_configs
  end

  def self.config_vms(vms = nil)
    return if !Mr::enabled?
    @vm_configs.keys().each() do |v|
      Vuppeteer::trace('config VM', v)
      match = vms.nil? || (vms.is_a?(Array) && vms.include?(v)) || (vms.is_a?(Hash) && vms.has_key?(v))
      self._config(v) if match
      Vuppeteer::say("skipping config of #{v}") if !match
    end
    @vm_configs
  end

  def self.version()
    @version
  end

  ##
  # sets up standard triggers for Mr
  def self.register_triggers!()
    Triggers::register!(@vagrant) if Mr::enabled?
  end
  
  def self.host_pre_puppet_triggers() #TODO move int into Triggers::?
    return if !Mr::enabled?
    @vagrant.trigger.before [:up, :provision, :reload, :resume] do |trigger|
      trigger.info = 'Checking, are Strings Attached?'
      trigger.ruby do |env, machine|
        PuppetManager::pre_puppet()
        Vuppeteer::perform_host_commands(PuppetManager::get_host_commands('pre_puppet'))
      end
    end
  end

  #TODO does it make sense for this to stay here? pass trigger back to vuppeteer?
  def self.store_say(s, t) 
    if Triggers::triggered?(t)
      print s
    else
      Triggers::store_say(s, t)
    end
  end

  def self.halt_vb_guest()
    @features[:vb_middleware] = false
    Vuppeteer::say('Notice: VirtualBox Guest Additions Plugin Autoloading Disabled.', :prep);
  end

  def self.init_plugins(vm)
    Plugins::init()
  end

  def self.plugin_managing?(p, v)
    Plugins::managing?(p, v)
  end

  def self.plugin(p, v)
    Plugins::setup(p, v) if Mr::enabled?
  end

  def self.setup_helpers(h = nil, v = nil)
    return if !Mr::enabled?
    vms = ElManager::catalog(v.nil? ? :active : v)
    vms.each() do |c|
      Helpers::setup(h, @vm_configs[c]) if @vm_configs.has_key?(c)
    end
  end

  def self.flush_trigger_buffer()
    Triggers::flush()
  end

  #################################################################
    private
  #################################################################

  def self._build(vm, label)
    @vm_configs[label] = vm
  end

  def self._config(label)
    @vm_configs[label].box = ElManager::box(label)
    throttle = Network::throttle() #NOTE this isn't handled per vm yet
    @vm_configs[label].box_download_options = {"limit-rate": throttle} if throttle 
    #Vuppeteer::trace('configuring', label, ElManager::box(label))
    if (label.nil? || !@setup.include?(label))
      vm_string = label.nil? ? 'vm' : "vm:#{label}" 
      Vuppeteer::say("Notice: No custom vagrant configuration for #{vm_string} detected, using default setup")
    end
    vm_setup = label.nil? || !@setup.has_key?(label) ? @setup[:default] : @setup[label]
    Vuppeteer::trace('Vagrant config check', label, vm_setup, @setup, @setup[:default])
    ##
    # providers
    @vm_configs[label].provider 'virtualbox' do |vb|
      vb.name = label
      ##TODO we can probably streamline builds with linked clones
      #vb.linked_clone = true if Gem::Version.new(Vagrant::VERSION) >= Gem::Version.new('1.8.0')
      vb.gui = vm_setup && vm_setup.has_key?('gui') ? vm_setup['gui'] : false
      vb.memory = vm_setup && vm_setup.has_key?('memory') ? vm_setup['memory'] : '1024'
    end

    if (vm_setup && vm_setup.is_a?(Hash))
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
        h = n[1].is_a?(Hash) ? MrUtils::sym_keys(n[1]) : n[1]
        Vuppeteer::trace('vagrant network', n[0],h)
        @vm_configs[label].network n[0], **h
      end

      ##
      # shared folders
      shared = vm_setup.has_key?('synced_folder') ? vm_setup['synced_folder'] : []
      shared.each do |s|
        h = MrUtils::sym_keys(s[2])
        #TODO warn if there is no explicit type:
        st = s[1].is_a?(String) ? s[1] : self._lookup(s[1], label)
        @vm_configs[label].synced_folder s[0], s[1], h 
      end

      #TODO make sure guest_path is set from facts when present
      #VagrantManager::config().vm.synced_folder '.', @guest_path, owner: 'vagrant', group: 'vagrant', type: 'virtualbox'
    end
  end

  def self._linked_clone?(vm)
    return false if !@features.has_key?(:linked_clones) 
    return @features[:linked_clones].is_a?(TrueClass) || (@features.respond_to?('include?') && @features.include?(vm))
  end

  def self._lookup(sym, vm_name)
    case sym
    when :guest_root
      return PuppetManager.guest_root(vm_name) #TODO ?? should be ::guest_root(...?
    end
    Vuppeteer::shutdown("Error: Unrecognized Puppet binding #{sym.to_s} called on #{vm_name}", -5)
  end

end