## 
# Encapsulates RHEL specifics for for MrRogers
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/ 
# https://www.linux.ncsu.edu/rhel-unc-system/
#

module ElManager
  extend self

  require_relative 'el/network'
  require_relative 'el/collections'
  
  @singleton = nil
  @build = 'hobo'
  @box = 'generic/rhel7'
    # #   @box_source = 'centos/7'
  @ident_file = 'puppet/license_ident.yaml'
  @custom_sc = nil
  @custom_setup = nil
  @custom_update = nil
  @destroy_script = nil
  @cred_keys = ['org','key','user','pass','host']
  @cred_type = [nil, 'org','user'][0]
  @known_box_prefixes = ['generic/rhel'];

  def self.init()

  end

  def self._old_init(hash_or_key = nil, source_box = nil)
    @destroy_script = 'rhel_destroy' #TODO this whouldn't be set when in Centos/Nomad mode...
    @box = source_box if !source_box.nil?
    return self if !hash_or_key
    return self._lookup_ident(hash_or_key) if !hash_or_key.class.include?(Enumerable)
    self._init_hash(hash_or_key)
  end

  def self.el_version()
    return nil if !@box || !self.is_it?()
    return self._get_box_el_version(@box)
  end

  def self._lookup_ident(ident_key)
    rhel_data = FileManager::load_config_yaml(@ident_file, 'RHEL')
    reg_data = rhel_data[ident_key] if rhel_data
    reg_data['ident'] = ident_key if (!reg_data['ident']) && rhel_data
    rc = 'RHEL registration configuration'
    if (!reg_data) 
      if (ident_key == 'nomad')
        Vuppeteer::say("Warning: No default #{rc} specified, using fallback setup", 'prep')
      else
        Vuppeteer::say("Error: #{rc} for \"#{ident_key}\" is not available")
        Vuppeteer::say("  specify 'nomad' to attempt the default fallback configuration")
        Vuppeteer::shutdown("Error: Invalid #{rc} entry")
      end
    else
      incomplete_config_text = "Warning: #{rc} for \"#{ident_key}\" is incomplete"
      facts = Vuppeteer::facts()
      complete_custom = reg_data.include?('custom_setup')
      @cred_type = self.ready_to_register()
      incomplete = !complete_custom && !@cred_type
      if (@cred_type)
        @cred_keys.each {|k| reg_data["rhsm_#{k}"] = facts["rhsm_#{k}"] if facts.include?("rhsm_#{k}")}
      end
      Vuppeteer::say(incomplete_config_text, 'prep') if incomplete
    end
    self.init_hash(reg_data)
  end

  def self.ready_to_register()
    facts = Vuppeteer::facts()
    complete_org = ['rhsm_org', 'rhsm_key'].all? {|k| facts.include?(k)}
    complete_user = ['rhsm_pass', 'rhsm_user'].all? {|k| facts.include?(k)}
    return 'org' if complete_org
    return 'user' if complete_user
  end

  def self.init_hash(ident_hash)
    @build = ident_hash.fetch('box_suffix', ident_hash['ident'])
    @box = ident_hash.fetch('box', @box)
    el_version = self._get_box_el_version(@box)
    if (el_version == '8')
      VagrantManager::halt_vb_guest() #TODO this should be in plugin-manager? right now it's vb middle ware, so not a "plugin"?
    end
    if ident_hash['custom_sc'] #TODO make this more robusty
      #Vuppeteer::say("binding custom sc: " + Mr::path("#{org_hash['custom_sc']}"))
      @custom_sc = ident_hash['custom_sc']
    end
    if ident_hash['custom_setup'] #TODO make this more robusty
      #Vuppeteer::say("binding custom setup: " + Mr::path("#{org_hash['custom_setup']}"))
      @custom_setup = ident_hash['custom_setup']
    end
    if ident_hash['custom_update'] #TODO make this more robusty
      #Vuppeteer::say("binding custom update: " + Mr::path("#{org_hash['custom_update']}"))
      @custom_update = ident_hash['custom_update']
    end
    if ident_hash['custom_destroy'] #TODO make this more robusty
      #Vuppeteer::say("binding custom update: " + Mr::path("#{org_hash['custom_update']}"))
      @destroy_script = ident_hash['custom_destroy']    
    end
    if ident_hash['software_collection'] #TODO make this more robusty
      Vuppeteer::set_facts({'software_collection' => ident_hash['software_collection']}, true)
    end
    ident_hash['el_version'] = el_version
    @singleton = Realm.new(ident_hash)
  end

  def self.box()
    @box
  end

  def self.sc()
    return @custom_sc
  end

  def self.sc_commands()
    has_sc_repos = CollectionManager::sc_repos().length > 0
    return ErBash::script(@custom_sc, RhelManager::credentials()) if @custom_sc
    return ErBash::script('rhel_dev_sc', RhelManager::credentials()) if has_sc_repos
    return <<-SHELL
        echo Including the software_collections...
        echo none configured...
      SHELL
        # subscription-manager repos --enable rhel-server-rhscl-7-rpms
        # subscription-manager repos --enable rhel-7-server-optional-rpms
  end

  def self.setup()
    setup_script = @cred_type == 'user' ? 'rhel_developer_setup' : 'rhel_setup'
    return ErBash::script(@custom_setup, RhelManager::credentials()) if @custom_setup
    ErBash::script(setup_script, RhelManager::credentials())
  end

  def self.update()
    return ErBash::script(@custom_update, RhelManager::credentials()) if @custom_update
    ErBash::script('rhel_update', RhelManager::credentials())
  end

  def self.unregister()
    ErBash::script(@destroy_script, RhelManager::credentials())
  end

  def self.box_destroy_prep()
    return if !@destroy_script
    VagrantManager::set_destroy_trigger(@destroy_script)
  end

  def self.collection_manifest()
    self.is_it? ? '' : '-sc:centos'
  end

  def self.credentials()
    @singleton&.view()
  end

  def self.is_it?()
    @singleton != nil
  end

  def self.build()
    @build
  end

  ## came from Vuppeteer
    # def self.name_gen()
    #   return Vuppeteer::get_fact('box_name') if Vuppeteer::fact?('box_name')
    #   app = Vuppeteer::get_fact('app', '')
    #   developer = Vuppeteer::get_fact('developer', '')
    #   fallback = [app, developer].all?{|v| v == ''} ? 'vagrant-puppet' : ''
    #   delim = [app, developer].none?{|v| v == ''} ? '-' : ''
    #   "#{developer}#{delim}#{app}#{fallback}"
    # end
  
    # def self.infra_gen()
    #   return '' if Vuppeteer::fact?('standalone')  
    #   RhelManager::is_it? ? RhelManager::build() : 'nomad'
    # end

  def self.register()
    
    NetworkManager::resgister(cors)#app = nil, developer = nil #self._register(Vuppeteer::get_fact('org_domain'))
    ## came from Mr
  #     if (RhelManager::is_it?)
  #       RhelManager::box_destroy_prep()
  
  #       if (VagrantManager::plugin_managing?(:registration))
  #         VagrantManager::plugin(:setup_registration)
  #       else
  #         VagrantManager::config().vm.provision 'register', type: :shell do |s|
  #         end
  #       end
  #       registration_update_inline = RhelManager::update()
  #       VagrantManager::config().vm.provision 'unregister', type: :shell, run: 'never' do |s|
  #         s.inline = RhelManager::unregister()
  #       end
  #     else
  #       VagrantManager::config().vm.provision 'register', type: :shell do |s|
  #         s.inline = ErBash::script('centos_setup')
  #       end
  #       VagrantManager::config().vm.provision 'unregister', type: :shell, run: 'never' do |s|
  #         s.inline = unavailable_script
  #       end
  #       registration_update_inline = unavailable_script
  #     end
  
  #     VagrantManager::config().vm.provision 'update_registration', type: :shell, run: @when_to_reregister do |s|
  #       s.inline = registration_update_inline
  #     end
      
  #     VagrantManager::config().vm.provision 'refresh', type: :shell, run: 'never' do |s|
  #       s.inline = ErBash::script('yum_refresh')
  #     end

    CollectionManager::provision(VagrantManager::config()) #TODO this may be deprecated since it is tied to RHEL7?
  end

  def self._setup()
    ## came from Mr
#     if Vuppeteer::fact?('box_source')
  #       @box_source = Vuppeteer::get_fact('box_source')
  #     elsif Vuppeteer::get_fact('default_to_rhel')
  #       @box_source = RhelManager::box()
  #     end
  #     license_important = Vuppeteer::get_fact('license_important', false)
  #     if (license_important)
  #       selected_license = Vuppeteer::get_fact('license_ident', Vuppeteer::get_fact('pref_license_ident', nil))
  #     else
  #       selected_license = Vuppeteer::get_fact('pref_license_ident', Vuppeteer::get_fact('license_ident', nil))
  #     end
  #     RhelManager::init(selected_license, @box_source)
  #     #TODO software_collection = ''; #TODO! RhelManager::collection_manifest()
  end

  def self._get_box_el_version(box_name)
    @known_box_prefixes.each do |b|
      if (box_name.start_with?(b))
        return box_name.slice(b.length..-1)
      end
    end
    return box_name.slice(-1)
  end

  #TODO before destroy, unregister

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
        @rhel_user = hash['rhsm_user'] if hash&.include?('rhsm_user')
        @rhel_pass = hash['rhsm_pass'] if hash&.include?('rhsm_pass')
        @rhel_org = hash['rhsm_org'] if hash&.include?('rhsm_org')
        @rhel_key = hash['rhsm_key'] if hash&.include?('rhsm_key')
        @key_repo = hash['key_repo'] if hash&.include?('key_repo')
        @rhel_server = hash['rhsm_server'] if hash&.include?('rhsm_server')
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

    #TODO add a pre/post destroy hook for unregistering the VM from RHEL

    def dev_tools_needed()
      return true
    end

    #TODO add back in attaching a key via repo as a view option

    def dev_tools_command()
      'yum groups install "Development Tools" -y'
    end

    def sc_pending()
      return CollectionManager::requested?()
    end

    def rhel_sc_repos()
      CollectionManager::sc_repos()
    end

    def rhel_sc_repos_enabled()
      CollectionManager::enabled_sc_repos()
    end
  end

end