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
    l = "#{Mr::active_path()}/#{FileManager::localize_token}.hiera/#{facet}"
    [l, "#{l}.yaml"].each do |f|
      return true if File.exist?(f)
    end
    false
  end

  def self.project_override?(facet)
    return false if !Vuppeteer::enabled?(:hiera)
    p = "#{Mr::active_path()}/hiera/#{facet}"
    [p, "#{p}.yaml"].each do |f|
      return true if File.exist?(f)
    end
    false
  end

  def self.global_override?(facet)
    return false if !Vuppeteer::enabled?(:hiera) || Vuppeteer::external?()
    g = "#{Mr::active_path()}/global.hiera/#{facet}"
    path = 
    [g, "#{g}.yaml"].each do |f|
      return true if File.exist?(f)
    end
    false
  end

  def self.external_override?(facet)
    return false if !Vuppeteer::enabled?(:hiera) || !Vuppeteer::external?()
    e = "#{Vuppeteer::external_path}/hiera/#{facet}"
    [e, "#{e}.yaml"].each do |f|
      #Vuppeteer::say("checking for #{facet}, #{f}")
      return true if File.exist?(f)
    end
    false
  end

  def self.scan_modules(facet)
    file = self.source(facet)
    #TODO handle multiple files as intended...
    #Vuppeteer::trace('scanning hiera file', facet, file)
    return [] if !file
    lines = FileManager::scan(file, '@requires')
#    Vuppeteer::say([__FILE__,__LINE__,facet, lines].to_s)
    modules = []
    lines.each() do |l|
      modules.push(l.split(','))
    end
    MrUtils::clean_whitespace(modules.flatten())
  end

  def self.required_modules()
    return @required_modules
  end

  def self.source(facet)
    l = self.local(facet)
    p = self.project(facet)
    g = self.global(facet)
    e = self.external(facet)
    return FileManager::first_match([p, "#{p}.yaml"]) if self.project_override?(facet)
    return FileManager::first_match([l, "#{l}.yaml"]) if self.local_override?(facet)
    return FileManager::first_match([g, "#{g}.yaml"]) if !Vuppeteer::external? && self.global_override?(facet)
    return FileManager::first_match([e, "#{e}.yaml"]) if Vuppeteer::external? && self.external_override?(facet)
    nil
  end

  def self.generate()
    if (!Vuppeteer::enabled?(:hiera)) 
      Vuppeteer::say('Notice: Hiera support disabled', :prep)
      return nil
    end
    stack = Vuppeteer::get_stack(:hiera) + ["#{FileManager::localize_token()}.instance"]
    FileManager::clear!(@local_path)
    data_path = "#{@local_path}/data"
    FileManager::path_ensure(data_path, true)
    files = self._generate()
    handled_f = []
    stack.each do |f|
      next if handled_f.include?(f)
      handled_f.push(f)
      file = self.source(f)
      if (!file)
        Vuppeteer::report('stack_hiera', f, 'unavailable')
        next
      end
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
              Vuppeteer::report('stack_hiera', f, "empty.#{self._label(file)}")
            end
          rescue SystemCallError => e #TODO handle yaml parse errors
            malformed = "unable to load facts in hiera file \"#{c}\",#{e.to_s}, skipping"
            # print e.to_s + " \n\r"
            Vuppeteer::say("Notice: #{malformed}")
            Vuppeteer::report('stack_hiera', f, "invalid.#{self._label(file)}")
          end
        end
      end
      Vuppeteer::report('stack_hiera', f, self._label(file))
    end
    erb_source = FileManager::path(:template, @source_template)
    if (!erb_source || !File.exist?("#{erb_source}/#{@source_template}")) 
      #Vuppeteer::trace('hiera error trace', erb_source, @source_template)
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

  def self.local(facet = nil)
    file = facet ? "/#{facet}" : ''
    l = "#{Mr::active_path()}/#{FileManager::localize_token()}.hiera#{file}"
  end

  def self.project(facet = nil)
    file = facet ? "/#{facet}" : ''
    p = "#{Mr::active_path()}/hiera#{file}"
  end

  def self.global(facet = nil)
    file = facet ? "/#{facet}" : ''
    g = "#{Mr::active_path()}/global.hiera#{file}"
  end

  def self.external(facet = nil)
    file = facet ? "/#{facet}" : ''
    e = "#{Vuppeteer::external_path}/hiera#{file}" 
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

  def self._label(file)
    return 'local' if file.start_with?(self.local())
    return 'project' if file.start_with?(self.project())
    return 'global' if file.start_with?(self.global())
    return 'external' if file.start_with?(self.external())
    return nil
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