## 
# Encapsulates software collection management for Mr
# NOTE: SCL seems to be deprecated with RHEL8? so this module may be replaces with one more focuses on Yum Modules?
#

module Collections
  extend self

  @collections_requested = {default: false}
  @collections_added = false
  @collection_sources = ['rhel', 'centos', 'remi']
  @collection_source = {default: nil}
  @when_to_install_sc = ['once', 'never'][0]

  def self.request(sc_name = nil, w = :default)
    @collections_requested[w] = !sc_name.nil?
    @collection_source[w] = sc_name if sc_name
  end

  def self.provision(v, which = nil)
    #TODO add source? even if @collections_added?
    which = :default if v.nil? || !@collections_requested.has_key?(which)
    if (@collections_requested[which] && !@collections_added)
        v.provision "software_collections", type: :shell, run: self.run_when() do |s|
          s.inline = ElManager::is_it?() ? ElManager::sc_commands() : self.commands()
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

  def self.package_view(name)
    return Package.new(name).view()
  end

  def self.credentials(w = :default)
    return ElManager::credentials(w) #if ElManager::is_it?(w)
    #return Credentials.new().view()
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

  # class Credentials #TODO this should be deprecated, or replace ElManager::Realm
  #   @el_version = '7'
  #   def initialize()
  #   end

  #   def view()
  #     return binding()
  #   end
  # end

end