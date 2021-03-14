## 
# Encapsulates RHEL specifics for for MrRogers
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/ 
# https://www.linux.ncsu.edu/rhel-unc-system/
#

module ElManager
  extend self

  require_relative 'el/boxes'
  require_relative 'el/network'
  require_relative 'el/collections'
  
  @singletons = {}
  @multibuild = nil
  @el_data_source = 'el'
  @el_data = nil
  @el_version = {default: '8', null: '8'}
  @box = {default: 'generic/rhel8', null: 'generic/rhel8'}
  @fallbox = 'generic/fedora28'
  @ident = {default: nil}
  @sc = {default: nil}  

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
  @cred_type = [nil, :org, :user][0]
  @cred_types = {
    org: ['org', 'key'],
    user: ['user', 'pass'],
  }

  # @known_box_prefixes = ['generic/rhel'];
  # @box_options = []
  # @el_options = []

  def self.multi_vm()
    @multibuild = true if @multibuild.nil?
  end

  def self.init()
    @multibuild = false if @multibuild.nil?
    detected = self._detect_ident()
    @ident[:default] = detected ? self._validate(detected) : {}
    self._detect_version()
    self._detect_box()
    @ident[:default]['el_version'] = @el_version[:default]
    @ident[:default]['box'] = @box[:default]
    @singletons[:default] = Realm.new(@ident[:default])
    # @cred_types.each() do |t, r|
    #   s = r.map {|c| "#{@cred_prefix}#{c}"}
    # end
    #TODO Vuppeteer::mark_sensitive([sensitive ident keys])
    VagrantManager::halt_vb_guest() if @el_version[:default] == '8' #TODO this should be in plugin-manager? right now it's vb middle ware, so not a "plugin"?
    @scripts[:default][:destroy] = 'rhel_destroy' #if self.is_it? #TODO this whouldn't be set when in Centos/Nomad mode...
    # if ident_hash['software_collection'] #TODO make this more robusty
    #   Vuppeteer::set_facts({'software_collection' => ident_hash['software_collection']}, true)
    # end
    @scripts[:null].keys().each() do |s|
      k ="custom_#{s.to_s}"
      @scripts[:default][s] = @ident[:default][k] if @ident[:default].has_key?(k)
    end
  end

  def self.el_version(w = :default)
    @el_version[w]
  end

  def self.box(w = :default)
    @box[w]
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
      Collections::request(Vuppeteer::get_fact('software_collection', @sc))
    end
  end

  def self.ready_to_register(ident = nil, validation = nil)
    ident = @ident if ident.nil?
    p = validation.nil? ? @cred_prefix : ''
    validation = @cred_types if validation.nil?
    validation = {custom: validation} if validation.class == Array
    validation.each() do |t, r|
      requires = r.map {|k| "#{p}#{k}"}
      return t if requires.all? { |k| ident.include?(k)}
    end
  end

  def self.script(w, flavor = :default)
    return @scripts[flavor].has_key?(w) ? @scripts[flavor][w] : nil
  end

  def self.sc_commands()
    #TODO lookup os flavor for self.scripts
    has_sc_repos = Collections::repos().length() > 0
    return FileManager::bash(self.script(:sc), self.credentials()) if self.script(:sc)
    return FileManager::bash('rhel_dev_sc', self.credentials()) if has_sc_repos
    return <<-SHELL
        echo Including the software_collections...
        echo none configured...
      SHELL
        # subscription-manager repos --enable rhel-server-rhscl-7-rpms
        # subscription-manager repos --enable rhel-7-server-optional-rpms
  end

  def self.setup_script()
    setup_script = self._detect_setup_script()
    return FileManager::bash(self.script(:setup), self.credentials()) if self.script(:setup)
    FileManager::bash(setup_script, self.credentials())
  end

  def self.update_script()
    return FileManager::bash(self.script(:update), self.credentials()) if self.script(:update)
    FileManager::bash('rhel_update', self.credentials())
  end

  def self.unregister_script()
    FileManager::bash(self.script(:destroy), self.credentials())
  end

  def self.collection_manifest()
    self.is_it? ? '' : '-sc:centos'
  end

  def self.credentials(w = :default)
    @singletons[w]&.view()
  end

  def self.is_it?(w = :default)
    @singletons[w] != nil
  end

  def self.register(vms = nil)
    #Vuppeteer::trace(vms)
    vms = MrUtils::enforce_enumerable(vms)
    vms = VagrantManager::get_vm_configs(vms) if vms.class == Array
    #Vuppeteer::trace(vms)
    vms.each() do |n, v|
      cors = Vuppeteer::get_fact('org_domain') #TODO this could be different per VM
      Network::register(cors)#app = nil, developer = nil #self._register(Vuppeteer::get_fact('org_domain'))
      if (self.is_it?)
        self._box_destroy_prep()
        if (VagrantManager::plugin_managing?(:registration))
          VagrantManager::plugin(:setup_registration)
          v.provision 'register', type: :shell, run: 'never' do |s|
            s.inline = 'echo Vagrant plugin is managing registration'
          end
        else
          v.provision 'register', type: :shell do |s|
          end
        end
        registration_update_inline = self.update_script()
        v.provision 'unregister', type: :shell, run: 'never' do |s|
          s.inline = self.unregister_script()
        end
      else
        v.provision 'register', type: :shell do |s|
          s.inline = FileManager::bash_script('fedora_setup')
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
        s.inline = FileManager::bash('yum_refresh')
      end

      Collections::provision(v) #TODO this may be deprecated since it is tied to RHEL7?
    end
  end

  def self.cred_prefix()
    @cred_prefix
  end

  def self.configure_plugin(plugin, name)
    #TODO case name #we only support one plugin right now...
    mode = self.ready_to_register()
    case mode
    when :user
      plugin.username = @ident[:user] #Vuppeteer::get_fact('rhsm_user')
      plugin.password = @ident[:pass] #Vuppeteer::get_fact('rhsm_pass')
    when :org
      plugin.org = @ident[:org] #Vuppeteer::get_fact('rhsm_org')
      plugin.activationkey = @ident[:key] #Vuppeteer::get_fact('rhsm_key')
    end
    plugin.skip = false
    #p.auto_attach = false if @ident.has_key?(:manual_attach) && @ident[:manual_attach] # only do this on dev?
  end

  def self.get_vms(n)
    return Boxes::get(n)
  end

  #################################################################
  private
  #################################################################

  def self._detect_ident()
    @el_data = Vuppeteer::load_facts(@el_data_source, 'Notice:(EL Configuration)')
    license = self._negotiate()
    el_license = @el_data && license && @el_data.has_key?(license) ? @el_data[license] : nil
    # if(!el_license)
    #   el_data = Vuppeteer::load_facts("#{FileManager::localize_token}.el.yaml", false)
    #   el_license = el_data && license && el_data.has_key?(license) ? el_data[license] : nil
    # end
    # if(!el_license)
    #   el_data = Vuppeteer::load_facts('::licenses', false)
    #   el_license = el_data && license && el_data.has_key?(license) el_data[license] ? : nil
    # end
    el_license
  end 

  def self._negotiate()
    license_important = Vuppeteer::get_fact('license_important', false)
    l = Vuppeteer::get_fact('el_license')
    d = Vuppeteer::get_fact('el_developer_license')
    #
    # x = Vuppeteer::get_fact('license')
    # x = Vuppeteer::get_fact('developer_license')
    # x = Vuppeteer::get_fact('el_min_version')
    # x = Vuppeteer::get_fact('licenses')
    # x = Vuppeteer::get_fact('developer_licenses')
    # x = Vuppeteer::get_fact('box_hit')
    # x = Vuppeteer::get_fact('license')
    license_important && l ? l : (d ? d : l)
  end

  def self._detect_box()
    d = Vuppeteer::get_fact('default_to_rhel', true)
    s = Vuppeteer::get_fact('box_source')
    @box_source = s ? s : @fallbox if s || !d
  end

  def self._detect_version()
    @el_version = Vuppeteer::get_fact('el_version') if Vuppeteer::fact?('el_version')
  end

  def self._validate(ident)
    return {} if @box_source == @fallbox
    if !ident
      Vuppeteer::say('Warning: No license detected...', 'prep') 
      return {}
    end
    incomplete_config_text = "Warning: license data is incomplete"
    custom = ident.include?('custom_requirements') ? ident['custom_requirements'] : nil 
    @cred_type = self.ready_to_register(ident, custom)
    if (custom && @cred_type)
      new_cred = custom.class == Array ? custom : custom[@cred_type] 
      @cred_types[@cred_type] = new_cred
    end
    if !@cred_type
      Vuppeteer::say(incomplete_config_text, 'prep')
      return {}
    end
    ident
  end

  def self._detect_setup_script() #TODO handle non-rhel
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

  def self._box_destroy_prep()
    return if !self.script(:destroy)
    VagrantManager::set_destroy_trigger(self.script(:destroy))
  end

  def self._suffix(data)
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

    def initialize(hash)
        p = ElManager::cred_prefix
        @rhel_user = hash["#{p}user"] if hash&.include?("#{p}user")
        @rhel_pass = hash["#{p}pass"] if hash&.include?("#{p}pass")
        @rhel_org = hash["#{p}org"] if hash&.include?("#{p}org")
        @rhel_key = hash["#{p}key"] if hash&.include?("#{p}key")
        @key_repo = hash['key_repo'] if hash&.include?('key_repo')
        @rhel_server = hash["#{p}server"] if hash&.include?("#{p}server")
        @dev_tools = Vuppeteer::get_fact('dev_tools') if hash&.include?('dev_tools')
        @man_attach = hash['manual_attach'] if hash&.include?('manual_attach')
        @el_version = hash['el_version'] if hash&.include?('el_version')
    end

    def view()
      return binding()
    end

    def register_options()
      return @rhel_server ? " --serverurl=\"#{@rhel_server}\"" : ''
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
  end

end