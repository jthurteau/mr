## 
# Builds Puppet Manifests for Mr
#

module Manifests
  extend self

  @manifest = nil
  @output_path = nil
  @build_token = 'mr made this'

  def self.init()
    @output_path = Mr::active_path if @output_path.nil?
    @manifest = "#{FileManager::localize_token}.pp" if @manifest.nil?
    FileManager::path_ensure("#{Mr::active_path}/manifests", FileManager::allow_dir_creation?)
    FileManager::path_ensure(@output_path, FileManager::allow_dir_creation?) if @output_path != Mr::active_path
  end

  def self.set_output_file(file)
    abs_path = File.absolute_path(file)
    Vuppeteer::shutdown('Invalid path for PuppetManifests, outside of writable path', -3) if !FileManager::may?(:write, abs_path)
    @manifest = File.basename(file)
    @manifest += ".pp" if !@manifest.end_with?('.pp')
    @output_path = File.dirname(file)
  end

  def self.generate()
    ldm_file = FileManager::tokened_file("#{@output_path}/#{@manifest}", [@build_token])
    if (ldm_file) #TODO more edge case testing around missing/unwritable ldm target
      Vuppeteer::say("building #{@manifest}", :prep)
      #ldm_file.truncate(ldm_file.pos + 1)
      ldm_file.truncate(ldm_file.pos)
      ppp_final = Vuppeteer::get_stack(:manifest) + ["#{FileManager::localize_token()}.instance"]
      required_modules = Hiera::required_modules()
      needed_modules = []     
      ppp_final.each do |pp|
        needed_modules = needed_modules + self._manifest(pp, ldm_file)
        #Vuppeteer::trace('needed after', pp, needed_modules)
      end
      needed_modules.each do |m|
          required_modules.push(m) if !required_modules.include?(m)
      end
      ldm_file.write("\n\r## \n\r# Hiera Required Modules\n\r") if required_modules.length > 0
      required_modules.each do |m|
        ldm_file.write("include #{m} \n\r")
      end
      #TODO appendix
      #self._appendix()
      ldm_file.close
    else
        Vuppeteer::say("Notice: Proceeding with manually written #{@manifest} !!!", :prep)
    end
  end

  def self.scan_modules(contents)
    lines = contents.split("\n")
    modules = []
    lines.each do |l|
      if (l.lstrip().start_with?('include'))
        contents = l.split('include', 2).last.split('#').first
        contents.split(',').each do |m|
          modules.push(m.split(MrUtils::splitter).first.split('\'').last)
        end
      end
    end
    modules
  end

  def self.path()
    @output_path
  end

  def self.file(v = nil) #TODO multi-vms may sometimes need multiple files
    @manifest
  end

  def self.source(facet)
    l = self.local(facet)
    p = self.project(facet)
    g = self.global(facet)
    e = self.external(facet) 
    return l if File.exist?(l)
    return p if File.exist?(p)
    return g if !Vuppeteer::external? && File.exist?(g)
    return e if Vuppeteer::external? && File.exist?(e)
    nil
  end

  def self.local(facet = nil)
    file = facet ? "/#{facet}.pp" : ''
    l = "#{Mr::active_path()}/#{FileManager::localize_token()}.manifests#{file}"
  end

  def self.project(facet = nil)
    file = facet ? "/#{facet}.pp" : ''
    p = "#{Mr::active_path()}/manifests#{file}"
  end

  def self.global(facet = nil)
    file = facet ? "/#{facet}.pp" : ''
    g = "#{Mr::active_path()}/global.manifests#{file}"
  end

  def self.external(facet = nil)
    file = facet ? "/#{facet}.pp" : ''
    e = "#{Vuppeteer::external_path}/manifests#{file}" 
  end

#################################################################
  private
#################################################################

  def self._manifest(s, ldm_file)
    needed_modules = [] #TODO push this up a level so we don't look up hiera each time?
    if (self._defer_to_hiera(s))
      hiera_exists = Hiera::source(s)
      Vuppeteer::report('stack_manifest', s, hiera_exists ? 'hiera' : 'absent')
      ldm_file.write("\n# #{s} handled in hiera \n") if hiera_exists
      modules = Hiera::scan_modules(s)
      modules.each do |m|
        needed_modules.push(m)
      end
      return needed_modules
    end
    manifest_source = self.source(s)
    if (manifest_source)
      Vuppeteer::report('stack_manifest', s, self._label(manifest_source))
      source_contents = File.read(manifest_source)
      ldm_file.write("\n\#\#\n\# from #{manifest_source}:\n#{source_contents}")
      needed_modules = self.scan_modules(manifest_source)
      return needed_modules
    end
    #Vuppeteer::trace('testing manifest', s, self._defer_to_hiera(s), self.source(s), self.external(s), File.exist?(self.external(s)), self.global(s), self.project(s),self.local(s))
    Vuppeteer::report('stack_manifest', s, 'absent')
    return []
  end

  def self._label(file)
    return 'local' if file.start_with?(self.local())
    return 'project' if file.start_with?(self.project())
    return 'global' if file.start_with?(self.global())
    return 'external' if file.start_with?(self.external())
    return nil
  end

  def self._defer_to_hiera(s)
    l = self.local(s)
    p = self.project(s)
    g = self.global(s)
    e = self.external(s) 
    # Vuppeteer::trace('testing hiera defer', s, {
    #   l: [l,File.exist?(l),Hiera::local_override?(s)], 
    #   p: [p,File.exist?(p),Hiera::project_override?(s)], 
    #   g: [g,!Vuppeteer::external? && File.exist?(g),Hiera::global_override?(s)], 
    #   e: [e, Vuppeteer::external? && File.exist?(e),Hiera::external_override?(s)]
    # })
    return Hiera::local_override?(s) if File.exist?(l)
    return Hiera::project_override?(s) if File.exist?(p)
    return Hiera::global_override?(s) if !Vuppeteer::external? && File.exist?(g)
    return Hiera::external_override?(s) if Vuppeteer::external? && File.exist?(e)
    return true
  end

end