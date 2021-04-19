## 
# Encapsulates RHEL specifics for for Mr
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/ 
# https://www.linux.ncsu.edu/rhel-unc-system/
#

module ElManager
  extend self

  require_relative 'license'
  require_relative 'boxes'
  require_relative 'machines'
  require_relative 'network'
  require_relative 'collections'
  
  @singletons = {}
  @multibuild = nil
  @conf_source = 'el'
  @el_data = nil
  @el_version = {default: '8', null: '8'}
  @box = {default: 'generic/rhel8', null: 'generic/rhel8'}
  @default_license =  'rhel8-dev'
  @cred_type = [nil, :org, :user][0] #TODO switch this for multi-vm
  @ident = {default: nil}
  #@fedora_translate = {'8' => '28', '7' => '24'} #TODO 28 and 29 won't work withough the vbguest plugin
  #@fedora_translate = {'8' => '30', '7' => '24'} #NOTE 30 is out of support and doesn't come with PHP7.4  
  @fedora_translate = {'8' => '32', '7' => '24'}  
  #@fedora_translate = {'8' => '33', '7' => '24'} #NOTE 33 doesn't have puppet support...
  @scripts = {
    default: {
      sc: nil,
      setup: nil,
      update: nil,
      destroy: nil
    },
    null: {
      sc: nil,
      setup: nil,
      update: nil,
      destroy: nil
    }
  }

  @cred_prefix = 'rhsm_'
  @cred_keys = ['org','key','user','pass','host']
  @cred_types = {
    org: ['org', 'key'],
    user: ['user', 'pass'],
  }

  @when_to_reregister = :never
  # @known_box_prefixes = ['generic/rhel'];
  # @box_options = []
  # @el_options = []

  def self.init()
    @multibuild = false if @multibuild.nil?
    detected = self._detect_ident()
    @ident[:default] = detected ? self._validate(detected) : {}
    #Vuppeteer::trace('EL Init validated', detected)
    self._detect_defaults()
    #Vuppeteer::trace('EL Init defaults', @box, @el_version, @ident[:default])
    flavor = self._flavor(@ident[:default]['box'])
    #Vuppeteer::trace('EL Init flavor', @ident[:default]['box'], self._flavor(@ident[:default]['box']))
    @ident[:default]['flavor'] = flavor if flavor
    @ident[:default]['flavor_version'] = @fedora_translate[@ident[:default]['el_version']] if flavor
    @ident[:default][:prefix] = @cred_prefix
#    @ident[:default]['plugin_registration'] = 
    @singletons[:default] = Realm.new(@ident[:default])
    self._load_credentials(:default) #TODO I assume these are used by the plug-in based registration... but seems like this should happen before instantiating the view
    #TODO Vuppeteer::mark_sensitive([sensitive ident keys])
    VagrantManager::halt_vb_guest() if @el_version[:default] == '8' #TODO this should be in plugin-manager? right now it's vb middle ware, so not a "plugin"?
    @scripts[:default][:destroy] = 'rhel_destroy' #if self.is_it? #TODO this whouldn't be set when in Centos/Nomad mode...
    # if ident_hash['software_collection'] #TODO make this more robusty
    #   @ident[:fefault]['sc'] = ident_hash['software_collection']
    # end
    @scripts[:null].keys().each() do |s|
      k ="custom_#{s.to_s}"
      @scripts[:default][s] = @ident[:default][k] if @ident[:default].has_key?(k)
    end
    host = Network::host_host().shift.downcase
    guest = Network::base_guest(Vuppeteer::facts(),self._suffix(Vuppeteer::facts()))
    vm_label = "#{host}_#{guest}"
    @singletons[:default].set('vm_name', vm_label) if Vuppeteer::get_fact('descriptive_registration')
  end

  def self.el_version(w = :default)
    @el_version.has_key?(w) ? @el_version[w] : @el_version[:default]
  end

  def self.box(w = :default)
    @box[@box.has_key?(w) ? w : :default]
  end

  def self.catalog(n = nil)
    #Vuppeteer::trace('catalog lookup', n)
    return Boxes::get() if (n.nil? || n == :all || n == :active) && !@multibuild
    names = []
    MrUtils::enforce_enumerable(n).each() do |v|
      names += Boxes::get(v)
    end
    names
  end

  def self.has?(v)
    return Boxes.include?(v)
  end

  def self.add(vm_name, conf_source = '::')
    if (vm_name.include?('#{')) 
      Boxes.proto(vm_name, conf_source)
    else
      Boxes.add(vm_name, conf_source)
    end
  end 

  def self.build() #TODO this might be deprecated
    @build
  end

  def self.setup()
    self._build_prototypes()
    if (@multibuild) 
      Vuppeteer::shutdown('attempting multi-vm provision' , -2)
      Boxes::all().each do |v|
        #Collections::request(Vuppeteer::get_fact('software_collection', @sc), group)
      end
    else
      box = "#{@box[:default]}:#{@el_version[:default]}"
      Vuppeteer::say("ElManager pre-setup config reports: #{box} " + @ident[:default].to_s) if Vuppeteer::enabled?(:debug)
      Collections::request(Vuppeteer::get_fact('software_collection'))
    end
  end

  def self.ready_to_register(ident = nil, validation = nil)
    #Vuppeteer::trace('testing ready_to_register', ident, validation, @ident)
    ident = @ident[ident] if ident.is_a?(Symbol) || ident.is_a?(String)
    ident = @ident[:default] if ident.nil?
    p = validation.nil? ? @cred_prefix : ''
    validation = @cred_types if validation.nil?
    validation = {custom: validation} if validation.is_a?(Array)
    #Vuppeteer::trace('tests', p, validation)
    validation.each() do |t, r|
      requires = r.map {|k| "#{p}#{k}"}
      #Vuppeteer::trace('testing', t, requires, ident)
      return t if requires.all? { |k| ident.include?(k.to_sym)}
    end
    false
  end

  def self.script(w, flavor = :default)
    return @scripts[flavor].has_key?(w) ? @scripts[flavor][w] : nil
  end

  def self.sc_commands(w = :default)
    #TODO lookup os flavor for self.scripts
    has_sc_repos = Collections::repos().length() > 0
    return FileManager::bash(self.script(:sc), self.credentials(w)) if self.script(:sc)
    return FileManager::bash('rhel_dev_sc', self.credentials(w)) if has_sc_repos
    return <<-SHELL
        echo Including the software_collections...
        echo none configured...
      SHELL
        # subscription-manager repos --enable rhel-server-rhscl-7-rpms
        # subscription-manager repos --enable rhel-7-server-optional-rpms
  end

  def self.setup_script(w = :default)
    setup_script = self.script(:setup) ? self.script(:setup) : self._detect_setup_script()
    begin
      #return FileManager::bash(self.script(:setup), self.credentials()) 
      FileManager::bash(setup_script, self.credentials(w))
    rescue => e
      return "echo 'unable to load setup script #{setup_script}'"
    end
  end

  def self.update_script(w = :default) #TODO this isn't setup for developer registration support
    begin
      return FileManager::bash(self.script(:update), self.credentials()) if self.script(:update)
      FileManager::bash('rhel_update', self.credentials(w))
    rescue => e
      return "echo 'unable to load update script rhel_update'"
    end
  end

  def self.unregister_script(w = :default)
    begin
      FileManager::bash(self.script(:destroy), self.credentials(w))
    rescue => e
      return "echo 'unable to load unregister script #{self.script(:destroy)}'"
    end
    
  end

  def self.collection_manifest(w = :default) #TODO deprecated?
    self.is_it?(w) ? '' : '-sc:centos'
  end

  def self.credentials(w = :default)
    return @singletons[w]&.view() if @singletons.has_key?(w)
    @singletons[:default].view()
  end

  def self.is_it?(w = :default) #TODO this needs work
    w = :default if !@singletons.has_key?(w)
    v = @box.has_key?(w) ? w : :default 
    # Vuppeteer::trace('rhel status', w,  @singletons, @singletons.has_key?(w), @box, v, 'flavor', self._flavor(@box[v]),@box[v])
    !self._flavor(@box[v]) && @singletons[w] != nil
  end

  def self.validate_vms(facts)
    vm_suffix = facts.fetch('standalone', false) ? '' : '#{s}'
    base_vm = Network::base_guest(facts, vm_suffix)
    if base_vm
      self.add(base_vm)
    elsif facts.has_key?('vms') && (!facts.has_key?('standalone') || !facts['standalone'])
      @multibuild = true if @multibuild.nil?
      vms = MrUtils::enforce_enumerable(self.get('vms'))
      if (vms.is_a?(Array)) 
        vms.each() do |c|
          c = Vuppeteer::load_facts(c, "VM Config #{c}") if c.is_a?(String)
          v = c.is_a?(Hash) && c.has_key?('vm_name') ? c['vm_name'] : FileManager::facet_split(c)[0].gsub('/', '-')
          if self.has?(v)
            Vuppeteer.say("Warning: duplicate vm build generated for #{v}", :prep)
            next            
          end
          self.add(v, c) if c.is_a?(Hash) && c.has_key?('enabled') && c['enabled']
        end
      else
        vms.each() do |v, c|
          c = Vuppeteer::load_facts(c, "VM Config #{v}") if c.is_a?(String)
          self.add(v, c) if c.is_a?(Hash) && c.has_key?('enabled') && c['enabled']
        end
      end
    end
  end

  def self.register(vms = nil)
    vms = MrUtils::enforce_enumerable(vms)
    vms = VagrantManager::get_vm_configs(vms) if vms.is_a?(Array)
    #Vuppeteer::trace('registering vms...')
    vms.each() do |n, v|
      Vuppeteer::trace('processing', n, 'is it RHEL?', self.is_it?(n))
      cors = Vuppeteer::get_fact('org_domain') #TODO this could be different per VM
      machine_id = ''
      developer = Vuppeteer::fact?('developer') ? Vuppeteer::get_fact('developer') : ''
      Network::throttle(Vuppeteer::get_fact('guest_throttle', nil))
      Network::cors_set(cors) #app = nil, developer = nil
      Network::passthrough_host(v, VagrantManager::get(:trigger), machine_id, developer)
      self._box_destroy_prep(n, self.is_it?(n))
      if (self.is_it?(n))
        #Vuppeteer::trace('registering', n, VagrantManager::plugin_managing?(:registration, n))
        if (VagrantManager::plugin_managing?(:registration, n))
          VagrantManager::plugin(:registration, n)
          v.provision 'register', type: :shell, run: 'never' do |s|
            s.inline = 'echo Vagrant plugin is managing registration'
          end
        else
          v.provision 'register', type: :shell do |s|
            s.inline = self.setup_script()
          end
        end
        registration_update_inline = self.update_script()
        v.provision 'unregister', type: :shell, run: 'never' do |s|
          s.inline = self.unregister_script()
        end
      else
        unavailable_script = "echo 'Unavailable when not using RHEL'"
        v.provision 'register', type: :shell do |s|
          begin
            s.inline = FileManager::bash('fedora_setup')
          rescue => e
            s.inline = "echo 'unable to load refresh script fedora_setup'"
          end
        end
        v.provision 'unregister', type: :shell, run: 'never' do |s|
          s.inline = unavailable_script
        end
        registration_update_inline = unavailable_script
      end

      v.provision 'update_registration', type: :shell, run: @when_to_reregister do |s|
        s.inline = registration_update_inline
      end
      
      v.provision 'refresh', type: :shell, run: 'never' do |s|
        begin
          s.inline = FileManager::bash('yum_refresh')
        rescue => e
          s.inline = "echo 'unable to load refresh script yum_refresh'"
        end
      end

      Collections::provision(v, n) #TODO this may be deprecated since it is tied to RHEL7?
    end
  end

  def self.cred_prefix()
    @cred_prefix
  end

  def self.use_registration_plugin(what = :default)
    #Vuppeteer::trace('El Manager checking registration settings', what, @ident)
    what = :default if !@ident.has_key?(what)
    @ident[what].has_key?('plugin_registration') && @ident[what]['plugin_registration']
    #self.is_it?(what) && '8' == self.el_version(what)
  end

  def self.configure_plugin(name, plugin, which)
    Vuppeteer::trace('configuring plugin', name, which)
    case name
    when :registration
      ident = MrUtils::sym_keys(@ident.has_key?(which) ? @ident[which] : @ident[:default])
      mode = self.ready_to_register(ident)
      Vuppeteer::('configuring', mode, ident)
      prefix = ident.has_key?(:prefix) ? ident[:prefix] : ''
      case mode
      when :user
        Vuppeteer::say('Configuring Registration Plugin for Developer Credentials', :prep)
        #Vuppeteer::trace('plugin', name, 'with', mode, prefix.to_s + 'user', ident, ident[(prefix.to_s + 'user').to_sym])
        plugin.username = ident[(prefix.to_s + 'user').to_sym] #Vuppeteer::get_fact('rhsm_user')
        plugin.password = ident[(prefix.to_s + 'pass').to_sym] #Vuppeteer::get_fact('rhsm_pass')
      when :org
        Vuppeteer::say('Configuring Registration Plugin for Organization Credentials', :prep)
        #Vuppeteer::trace('plugin', name, 'with', mode, ident[(prefix.to_s + 'org').to_sym])
        plugin.org = ident[(prefix.to_s + 'org').to_sym] #Vuppeteer::get_fact('rhsm_org')
        plugin.activationkey = ident[(prefix.to_s + 'key').to_sym] #Vuppeteer::get_fact('rhsm_key')
      else
        Vuppeteer::say("Warning: Unable to register with VM's configured ident")
      end
      plugin.skip = false
      #p.auto_attach = false if @ident.has_key?(:manual_attach) && @ident[:manual_attach] # only do this on dev?
    else
      Vuppeteer::say("Notice: plugin negotiation failed for: #{name.to_s}")
    end
  end

  def self.get_vms(n)
    return Boxes::get(n)
  end

  def self.puppet_install_script(vm_name)
    FileManager::bash('puppet_prep', Collections::credentials(vm_name))
  end

  #################################################################
  private
  #################################################################

  def self._detect_ident()
    @el_data = Vuppeteer::load_facts(@conf_source, 'Notice:(EL Configuration)')
    license = self._negotiate()
    @box[:default] = self._fallbox() if !license
    #Vuppeteer::trace('detect_ident', license, @box)
    el_license = @el_data && license && @el_data.has_key?(license) ? @el_data[license] : nil
    if el_license
      self._sign(el_license) if el_license
      @ident[license] = el_license if el_license
    end
    el_license
  end 

  def self._negotiate()
    license_important = Vuppeteer::get_fact('license_important', false)
    l = Vuppeteer::get_fact('el_license')
    d = Vuppeteer::get_fact('el_developer_license')
    r = license_important ? 'requires' : 'suggests'
    if (Vuppeteer::enabled?(:verbose)) 
      Vuppeteer::say("ElManager: Project #{r} license #{l}", :prep) if l
      Vuppeteer::say("ElManager: Project prefers license #{d}", :prep) if d
    end
    #
    # x = Vuppeteer::get_fact('license')
    # x = Vuppeteer::get_fact('developer_license')
    # x = Vuppeteer::get_fact('el_min_version')
    # x = Vuppeteer::get_fact('licenses')
    # x = Vuppeteer::get_fact('developer_licenses')
    # x = Vuppeteer::get_fact('box_hit')
    # x = Vuppeteer::get_fact('license')
    s = license_important && l ? l : (d ? d : @default_license)
    s_string = s.nil? ? 'none' : s
    Vuppeteer::say("ElManager: Selected license: #{s_string}", :prep) if Vuppeteer::enabled?(:verbose)
    s
  end

  def self._sign(l)
    return if l.nil?
    Vuppeteer::say('Notice: Mr signing EL License') if Vuppeteer::enabled?(:verbose)
    prefix = l.has_key?('cred_prefix') ? l['cred_prefix'] : @cred_prefix
    custom_keys = l.has_key?('cred_keys') ? MrUtils::enforce_enumerable(l['cred_keys']): nil
    default_keys = custom_keys.nil? ? @cred_keys.map {|k| "#{prefix}#{k}"} : nil;
    (custom_keys ? custom_keys : default_keys).each() do |k|
      l[k.to_sym] = Vuppeteer::get_fact(k) if !l.has_key?(k.to_sym) && Vuppeteer::fact?(k) 
    end
    #Vuppeteer::trace("checking signature", l.to_s)
  end

  def self._flavor(box)
    return nil if box.start_with?('generic/rhel')
    'fedora'
  end

  def self._detect_defaults()
    s = Vuppeteer::get_fact('box_source')
    d = Vuppeteer::get_fact('default_to_rhel', true)
    #Vuppeteer::trace('detection', s, d, Vuppeteer::get_fact('default_to_rhel'))
    @box[:default] = s ? s : self._fallbox() if s || !d
    # if (s)
    #   @box[:default] = s
    # elsif (!d) 
    #   @box[:default] = self._fallbox()
    # end
    @el_version[:default] = Vuppeteer::get_fact('el_version') if Vuppeteer::fact?('el_version')
    @ident[:default]['el_version'] = @el_version[:default]
    @ident[:default]['box'] = @box[:default]
  end

  def self._fallbox(el = nil)
    el = @el_version[:default] if el.nil?
    t = @fedora_translate[el]
    "generic/fedora#{t}"
  end

  def self._load_credentials(w)
    @ident[w] = @ident[:null].clone if !@ident.has_key?(w)
    c = @cred_keys.map {|s| "#{@cred_prefix}#{s}"}
    c.each() do |f|
      @ident[w][f] = Vuppeteer::get_fact(f) if Vuppeteer::fact?(f) 
    end
  end

  def self._validate(ident)
    return {} if @box[:default] == self._fallbox() #@box[:default] == @fallbox
    if !ident
      Vuppeteer::say('Warning: No license detected...', :prep) 
      return {}
    end
    incomplete_config_text = "Warning: license data is incomplete"
    custom = ident.include?('custom_requirements') ? ident['custom_requirements'] : nil 
    @cred_type = self.ready_to_register(ident, custom)
    if (custom && @cred_type)
      new_cred = custom.is_a?(Array) ? custom : custom[@cred_type] 
      @cred_types[@cred_type] = new_cred
    end
    if !@cred_type
      Vuppeteer::say(incomplete_config_text, :prep)
      return {}
    end
    ident
  end

  def self._detect_setup_script() #TODO handle non-rhel
    #Vuppeteer::trace('detecting setup script type', @cred_type.to_s)
    @cred_type == :user ? 'rhel_developer_setup' : 'rhel_setup'
  end

  def self._build_prototypes()
    p = Boxes::get(:all, true)
    p.each() do |b|
      c = Boxes::config(b, true)
      v = b.gsub('#{s}', self._suffix(Vuppeteer::get_fact(c)))
      Boxes::add(v, c)
    end
    #Vuppeteer::trace(p,Boxes::get(:all))
  end

  def self._box_destroy_prep(vm_name = nil, is_rhel) #TODO #1.0.0 multi-vm support
    return if !Mr::enabled?
    script = self.script(:destroy)
    if (is_rhel)
      trigger = VagrantManager::get(:trigger).before [:destroy] do |trigger|
        trigger.warn = 'Attempting to unregister this box and clear the instance facts before destroying...'
        trigger.on_error = :continue
        trigger.run_remote = {
          inline: FileManager::bash(script, self.credentials(vm_name))
        } if script
        trigger.ruby do |env, machine|
          Network::on_destroy(vm_name, env, machine)
        end
      end
    else
      trigger = VagrantManager::get(:trigger).before [:destroy] do |trigger|
        trigger.warn = 'Attempting to clear instance facts before destroying...'
        trigger.on_error = :continue
        trigger.ruby do |env, machine|
          Network::on_destroy(vm_name, env, machine)
        end
      end
    end
  end

  def self._suffix(data)
    #Vuppeteer::trace('building suffix, data:' , data)
    d = data.has_key?('developer') ? "-#{data['developer']}" : ''
    o = data.has_key?('org') ? "-#{data['org']}" : ''
    b = data.has_key?('box_source') ? data['box_source'] : @box[:default]
    fb = b.gsub('generic/' , '').gsub('/', '-')
    ident = nil #TODO
    l = false && self.ready_to_register(ident) == :user ? '-dev' : ''
    return "#{d}#{o}-#{fb}#{l}"
  end

  class Realm 
    @rhel_user = ''
    @rhel_pass = ''
    @rhel_org = ''
    @rhel_key = ''
    @key_repo = ''
    @rhel_server = ''
    @dev_tools = true
    @man_attach = false
    @el_version = '7'
    @el_flavor = nil
    @flavor_version = nil
    @vm = nil
    @data = {}

    def initialize(hash) #TODO yuck, clean this up
        p = ElManager::cred_prefix
        @rhel_user = hash["#{p}user".to_sym].to_s if hash&.include?("#{p}user".to_sym)
        @rhel_pass = hash["#{p}pass".to_sym].to_s if hash&.include?("#{p}pass".to_sym)
        @rhel_org = hash["#{p}org".to_sym].to_s if hash&.include?("#{p}org".to_sym)
        @rhel_key = hash["#{p}key".to_sym].to_s if hash&.include?("#{p}key".to_sym)
        @key_repo = hash['key_repo'] if hash&.include?('key_repo')
        @rhel_server = hash["#{p}server"] if hash&.include?("#{p}server")
        @dev_tools = Vuppeteer::get_fact('dev_tools') if hash&.include?('dev_tools')
        @man_attach = hash['manual_attach'] if hash&.include?('manual_attach')
        @el_version = hash['el_version'] if hash&.include?('el_version')
        @el_flavor = hash['flavor'] if hash&.include?('flavor')
        @flavor_version = hash['flavor_version'] if hash&.include?('flavor_version')
        @data = {}
    end

    def view()
      return binding()
    end

    def register_options()
      s = @rhel_server ? " --serverurl=\"#{@rhel_server}\"" : ''
      n = @data.has_key?('vm_name') ? " --name=\"#{@data['vm_name']}\"" : ''
      return "#{s}#{n}"
    end

    def attach_needed()
      return @man_attach
    end

    def attach_command()
      'subscription-manager attach'
    end

    def register_developer_options()
      options = ''
      options += "--org=\"#{@rhel_org}\" " if @rhel_org
      options += "--user=\"#{@rhel_user}\" " if @rhel_user
      options += "--password=\"#{@rhel_pass}\" " if @rhel_pass
      options += "--serverurl=\"#{@rhel_server}\" " if @rhel_server
      options += "--activationkey=\"#{@rhel_key}\" " if @rhel_key
      options
    end

    def dev_tools_needed()
      return @dev_tools
    end

    def dev_tools_command()
      'yum groups install "Development Tools" -y'
    end

    def sc_pending()
      return Collections::requested?()
    end

    def rhel_sc_repos()
      Collections::repos()
    end

    def rhel_sc_repos_enabled()
      Collections::enabled(:repos)
    end

    def fact(f, default = nil)
      Vuppeteer::get_fact(f, default)
    end

    def puppet_version()
      PuppetManager::version(@vm)
    end

    def set(k, v)
      @data[k] = v
    end

    def get(k)
      @data[k]
    end

    def set?(k)
      @data.has_key?(k)
    end

  end

end