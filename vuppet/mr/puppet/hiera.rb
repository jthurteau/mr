## 
# Manages Puppet Hiera for Mr
#

module Hiera
  extend self

  @conf_source = ['puppet.yaml::hiera','::hiera'][1]
  @local_path = ''
  @remote_path = ''
  @file = 'vagrant.yaml'
  @source_template = 'hiera.erb'
  @node_target = 'common.yaml'
  @deferred_manifests = []
  @required_modules = []
  @hiera_data = {default:{},}

  def self.init(remote_puppet)
    if (Vuppeteer::get_fact('hiera_disabled', false))
      PuppetManager::disable(:hiera)
      return 
    end
    if (@conf_source.start_with?(MrUtils::splitter))
      @conf = Vuppeteer::get_fact(@conf_source[2..-1], {})
    else
      @conf = Vuppeteer::load_facts(@conf_source, 'Notice:(Puppet Hiera Configuration)')
    end
    @local_path = "#{Mr::active_path()}/#{FileManager::path(:temp)}/hiera"
    @remote_path = "#{remote_puppet}/#{FileManager::path(:temp)}/hiera"
    hiera = @hiera_data[:default]
    requires = MrUtils::dig(hiera, 'requires')
    @required_modules = MrUtils::enforce_enumerable(requires) if requires
  end

  def self.config_path()
    "#{@local_path}/#{@file}"
  end

  def self.local_override?(facet)
    return false if !Vuppeteer::enabled?(:hiera)
    l = "#{Mr::active_path()}/#{FileManager::localize_token}.facts/#{facet}.hiera"
    [l, "#{l}.yaml"].each do |f|
      return true if File.exist?(f)
    end
    false
  end

  def self.project_override?(facet)
    return false if !Vuppeteer::enabled?(:hiera)
    p = "#{Mr::active_path()}/facts/#{facet}.hiera"
    [p, "#{p}.yaml"].each do |f|
      return true if File.exist?(f)
    end
    false
  end

  def self.global_override?(facet)
    return false if !Vuppeteer::enabled?(:hiera) || Vuppeteer::external?()
    g = "#{Mr::active_path()}/global.facts/#{facet}.hiera"
    path = 
    [g, "#{g}.yaml"].each do |f|
      return true if File.exist?(f)
    end
    false
  end

  def self.external_override?(facet)
    return false if !Vuppeteer::enabled?(:hiera) || !Vuppeteer::external?()
    e = "#{Vuppeteer::external_path}/facts/#{facet}.hiera"
    [e, "#{e}.yaml"].each do |f|
      #Vuppeteer::say("checking for #{facet}, #{f}")
      return true if File.exist?(f)
    end
    false
  end

  def self.handle(facet)
    @deferred_manifests.push(facet)
  end

  def self.scan_modules(facet)
    file = self.source(facet)
    return [] if !file
    lines = FileManager::scan(file, '@requires')
#    Vuppeteer::say([__FILE__,__LINE__,facet, lines].to_s)
    modules = []
    lines.each() do |l|
      modules.push(l.split(','))
    end
    MrUtils::clean_whitespace(modules.flatten()) #TODO file utils maybe?
  end

  def self.required_modules()
    return @required_modules
  end

  def self.source(facet)
    l = "#{Mr::active_path()}/#{FileManager::localize_token}.facts/#{facet}.hiera"
    p = "#{Mr::active_path()}/facts/#{facet}.hiera"
    g = "#{Mr::active_path()}/global.facts/#{facet}.hiera"
    e = "#{Vuppeteer::external_path}/facts/#{facet}.hiera"
    return FileManager::first_match([p, "#{p}.yaml"]) if self.project_override?(facet) #TODO these should be refactorable...
    return FileManager::first_match([l, "#{l}.yaml"]) if self.local_override?(facet)
    return FileManager::first_match([g, "#{g}.yaml"]) if self.global_override?(facet)
    return FileManager::first_match([e, "#{e}.yaml"]) if self.external_override?(facet)
    nil
  end

  def self.generate()
    if (!Vuppeteer::enabled?(:hiera)) 
      Vuppeteer::say('Notice: Hiera support disabled', :prep)
      return nil
    end
    FileManager::clear!(@local_path)
    data_path = "#{@local_path}/data"
    FileManager::path_ensure(data_path, true)
    files = self._generate()
    handled_f = []
    @deferred_manifests.each do |f|
      next if handled_f.include?(f)
      handled_f.push(f)
      file = self.source(f)
      #Vuppeteer::say("Notice : Hiera #{file} #{self.local_override?(facet).to_s }for #{f}")
      Vuppeteer::say("Warning: unable to source Hiera data for #{f}") if !file
      
      copied_files = FileManager::copy_unique(file, "#{data_path}/#{f}")
      # print copied_files.to_s + "\n"
      copied_files.each() do |c|
        c_ext = File.extname(c)
        c_base = File.basename(c, '.*')
        if (c_ext == '.yaml')
          begin
            yaml = YAML.load_file("#{data_path}/#{c}")
            if (yaml.class.include?(Enumerable))
              files.push("#{c_base}")
            else
              Vuppeteer::say("Notice: no facts in hiera file \"#{c}\", skipping")
            end
          rescue SystemCallError => e #TODO handle yaml parse errors
            malformed = "unable to load facts in hiera file \"#{c}\",#{e.to_s}, skipping"
            # print e.to_s + " \n\r"
            Vuppeteer::say("Notice: #{malformed}")
          end
        end
      end
    end
    erb_source = FileManager::path(:template, @source_template)
    if (!File.exist?("#{erb_source}/#{@source_template}")) 
      Vuppeteer::say('Error: Could not build Hiera Config, template unavailable!', :prep)
      return
    end
    #FileUtils.rm("#{self.config_path()}") if (File.exist?("#{self.config_path()}"))
    #FileUtils.cp("#{path}/#{@file_source}", "#{self.config_path()}")
    Vuppeteer::say("Notice: Building Hiera Data #{@remote_path}/#{@file}", :prep)
    source = File.read("#{erb_source}/#{@source_template}")
    view = self.view(files)
    contents = ERB.new(source).result(view)
    target = File.new("#{self.config_path()}", 'w+')
    target.write(contents)
    target.close()
    #TODO write a merged summary YAML of all data in hierarchy files (template to got o production puppet)
  end

  def self.view(files)
    Hiera.new(@remote_path, files).view()
  end



#################################################################
  private
#################################################################

  def self._generate()
    hiera = Vuppeteer::get_fact('hiera', {})
    files = [];
    data_path = "#{@local_path}/data"
    if (hiera['files'])
        hiera['files'].each do |f, v|
            FileManager::save_yaml("#{data_path}/#{f}.yaml", v)
            files.push(f)
        end
    end
    files
  end

  class Hiera 
    @data_path = nil
    @files = []
    @generated = []

    def initialize(remote, files)
        @data_path = "#{remote}/data"
        @files = files
        @generated = Vuppeteer::get_fact('hiera', {}).keys()
        
    end

    def view()
      return binding()
    end

    def translate(name)
        label_name = name.gsub('_', ' ').gsub(/^(\w)/) {|s| s.capitalize}
        (@generated.include?(name) ? 'Generated' : '') + label_name #TODO also indicate global, and external 
    end
  end

end