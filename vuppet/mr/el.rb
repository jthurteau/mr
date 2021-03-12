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
  @el_version = ['7','8'][0]
  @box = 'generic/rhel8'
  @ident_file = 'puppet/license_ident.yaml'

  @scripts = {
    sc: nil,
    setup: nil,
    update: nil,
    destroy: nil
  }

  @cred_keys = ['org','key','user','pass','host']
  @cred_type = [nil, :org, :user][0]
  @cred_types = {
    org: ['org', 'key'],
    user: ['user', 'pass'],
  }

  @cred_prefix = 'rhsm_'

  @known_box_prefixes = ['generic/rhel'];

  def self.init()
    @el_version = self._detect_version()
    @box = self._detect_box()
    @ident = self._detect_ident()
  end

  # def self._old_init(hash_or_key = nil, source_box = nil)
  #   @destroy_script = 'rhel_destroy' #TODO this whouldn't be set when in Centos/Nomad mode...
  #   @box = source_box if !source_box.nil?
  #   return self if !hash_or_key
  #   return self._lookup_ident(hash_or_key) if !hash_or_key.class.include?(Enumerable)
  #   self._init_hash(hash_or_key)
  # end

  def self.el_version()
    @el_version
  end

  def self.box()
    @box
  end

  def self.build() #TODO this might be deprecated
    @build
  end

  def self.ready_to_register()
    facts = Vuppeteer::facts()
    @cred_types.each() do |t, r|
      requires = r.map {|k| "#{@cred_prefix}#{k}"}
      return t if requires.all? { |k| Vuppeteer::facts().include?(k)}
    end
  end

  def self.setup()
# CollectionManager::request(Vuppeteer::get_fact('software_collection', RhelManager::sc))
  end

  def self.script(w)
    return @scripts.has_key?(w) ? @scripts[w] : nil
  end

  def self.sc_commands()
    has_sc_repos = Collections::repos().length() > 0
    return ErBash::script(self.script(:sc), self.credentials()) if self.script(:sc)
    return ErBash::script('rhel_dev_sc', self.credentials()) if has_sc_repos
    return <<-SHELL
        echo Including the software_collections...
        echo none configured...
      SHELL
        # subscription-manager repos --enable rhel-server-rhscl-7-rpms
        # subscription-manager repos --enable rhel-7-server-optional-rpms
  end

  def self.setup_script()
    setup_script = self._detect_setup_script()
    return ErBash::script(self.script(:setup), self.credentials()) if self.script(:setup)
    ErBash::script(setup_script, RhelManager::credentials())
  end

  def self.update_script()
    return ErBash::script(self.script(:update), self.credentials()) if self.script(:update)
    ErBash::script('rhel_update', RhelManager::credentials())
  end

  def self.unregister_script()
    ErBash::script(self.script(:destroy), self.credentials())
  end

  def self.box_destroy_prep()
    return if !self.script(:destroy)
    VagrantManager::set_destroy_trigger(self.script(:destroy))
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

  def self.cred_prefix()
    @cred_prefix
  end

#################################################################
private
#################################################################

  def self._detect_box()
    #   Vuppeteer::fact?('box_source') ? PuppetFacts::get_fact('box_source') : 
    # elsif PuppetFacts::get_fact('default_to_rhel')
    #   @box_source = RhelManager::box()
    # end
  end

  def self._detect_version()

  end

  def self._detect_ident()

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
    self._init_hash(reg_data)
  end

  def self._init_hash(ident_hash)
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

  def self._detect_setup_script() #TODO handle non-rhel
    @cred_type == :user ? 'rhel_developer_setup' : 'rhel_setup'
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

  #TODO deprecate
  def self._get_box_el_version(box_name)
    @known_box_prefixes.each do |b|
      if (box_name.start_with?(b))
        return box_name.slice(b.length..-1)
      end
    end
    return box_name.slice(-1)
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