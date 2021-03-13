## 
# Encapsulates software collection management for MrRogers
# NOTE: SCL seems to be deprecated with RHEL8? so this module may be replaces with one more focuses on Yum Modules?
#

module Collections
  extend self

  @collections_requested = false
  @collections_added = false
  @collection_sources = ['rhel', 'centos', 'remi']
  @collection_source = nil
  @when_to_install_sc = ['once', 'never'][0]

  def self.request(sc_name = nil)
    @collections_requested = !sc_name.nil?
    @collection_source = sc_name if (sc_name)
  end

  def self.provision(v, source = nil)
    #TODO add source? even if @collections_added?
    if (@collections_requested && !@collections_added)
        v.vm.provision "software_collections", type: :shell, run: self.run_when() do |s|
          s.inline = ElManager::is_it? ? ElManager::sc_commands() : self.commands()
        end
        self.retire()
    end
  end

  def self.commands()
    if ( @collection_source == 'centos' )
      software_collections_inline = <<-SHELL
      yum install centos-release-scl -y
      yum update -y
      SHELL
    elsif ( @collection_source == 'remi' )
      software_collections_inline = <<-SHELL
      yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
      yum update -y
      SHELL
    else
      software_collections_inline = <<-SHELL
      echo no valid software collection specified \\(requested '#{@collection_source}'\\)
      exit 1
      SHELL
    end
  end

  def requested?()
    @collections_requested
  end

  def self.retire()
    @collections_added = true
  end

  def self.run_when()
    return @when_to_install_sc
  end

  def package_view(name)
    return Package.new(name).view()
  end

  def credentials() #TODO make a CentosManager instead?
    return ElManager::credentials() if ElManager::is_it?
    return Credentials.new().view()
  end

  def self.repos()
    MrUtils::enforce_enumerable(Vuppeteer::get_fact('sc_repos', []))    
  end

  def self.enabled_sc_repos()
    #TODO this will require a cache of data from the guest?
    #TODO maybe implement with milestones
    #subscription-manager repos --list-enabled
    #alternative is to back out this method and store the output in a variable so we only have to run it once?
    []
  end

  class Package 
    @package = ''
    def initialize(p)
        @package = p
    end

    def view()
      return binding()
    end
  end

  class Credentials
    @el_version = '7'
    def initialize()
    end

    def view()
      return binding()
    end
  end

end