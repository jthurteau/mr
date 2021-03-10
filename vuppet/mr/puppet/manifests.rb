## 
# Builds Puppet Manifests for Mr
#

#TODO split our facts vs manifest building...
#TODO move the stack into puppeteer
module PuppetManifests
  extend self

  @manifest = nil
  @output_path = nil
  @build_token = 'mr made this'

  def self.init()
    path = Mr::active_path()
    @output_path = path if @output_path.nil?
    @manifest = "#{FileManager::localize_token}.pp" if @manifest.nil?
    FileManager::path_ensure(path + '/manifests', FileManager::allow_dir_creation?)
    FileManager::path_ensure(@output_path, FileManager::allow_dir_creation?) if @output_path != path
  end

  def self.set_output_file(file)
    abs_path = File.absolute_path(file)
    Vuppeteer::shutdown("Invalid path for PuppetManifests, outside of writable path", -3) if !FilePaths::may_write?(abs_path)
    @manifest = File.basename(file)
    @manifest += ".pp" if !@manifest.end_with?('.pp')
    @output_path = File.dirname(file)
  end

  def self.generate()
    ldm_file = FileManager::tokened_file("#{@output_path}/#{@manifest}", [@build_token])
    if (ldm_file) #TODO more edge case testing around missing/unwritable ldm target
      Puppeteer::say("building #{@manifest}", 'prep')
      ldm_file.truncate(ldm_file.pos + 1)
      ppp_final = PuppetStack::get() + ["#{FileManager::localize_token()}.instance"]
      required_modules = PuppetHiera::required_modules()
      needed_modules = []     
      ppp_final.each do |pp|
        needed_modules = needed_modules + self._manifest(pp)
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
        Puppeteer::say("Notice: Proceeding with manually written #{@manifest} !!!", 'prep')
    end
  end

  def self.scan_modules(contents)
    lines = contents.split("\n")
    modules = []
    lines.each do |l|
      if (l.lstrip().start_with?('include'))
        contents = l.split('include', 2).last.split('#').first
        contents.split(',').each do |m|
          modules.push(m.split('::').first.split('\'').last)
        end
      end
    end
    modules
  end

  def self.path()
    @output_path
  end

  def self.get_file()
    @manifest
  end

  def self.select(facet)
    l = self.local(facet)
    p = self.project(facet)
    g = self.global(facet)
    e = self.exernal(facet) 
    return l if File.exist?(l)
    return p if File.exist?(p)
    return g if !Vuppeteer::external? && File.exist?(g)
    return e if !Vuppeteer::external? && File.exist?(e)
    nil
  end

  def self.local(facet)
    l = "#{Mr::active_path()}/#{FileManager::localize_token()}.manifests/#{s}.pp"
  end

  def self.project(facet)
    p = "#{Mr::active_path()}/manifests/#{s}.pp"
  end

  def self.global(facet)
    g = "#{Mr::active_path()}/global.manifests/#{s}.pp"
  end

  def self.external(facet)
    e = "#{Vuppeteer::external_path}/manifests/#{s}.pp" 
  end

#################################################################
  private
#################################################################

  def self._manifest(s, ldm_file)
    #TODO rewrite this to use the Puppeteer::report mechanism 
    needed_modules = []
    return if s.include?('.') && !s.end_with?('.pp')
    s = s[0..-4] if s.end_with?('.pp')
    manifest_source = self.select(s)
    defer_to_hiera = false
    if (manifest_source)
      defer_to_hiera = self._defer_to_hiera(s)
      if (!defer_to_hiera)
        report_label = self._label(manifest_source)
        Puppeteer::report('manifest', s, label)
        ldm_file.write(source)
        source = File.read(manifest_source)
        needed_modules = self.scan_modules(manifest_source)
        return needed_modules
      end
    end
    if (defer_to_hiera)
      Puppeteer::report('manifest', s, 'hiera')
      ldm_file.write("\n\r# #{s} handled in hiera \n\r")
      modules = PuppetHiera::scan_modules(s)
      modules.each do |m|
        needed_modules.push(m)
      end
      PuppetHiera::handle(s)
      return needed_modules
    end
    Puppeteer::report('manifest', s, 'absent')
    return []
  end

  def self._label(file)
    return 'local' if file == self.local(s)
    return 'project' if file == self.project(s)
    return 'global' if file == self.global(s)
    return 'external' if file == self.external(s)
    return nil
  end

  def self._defer_to_hiera(s)
    l = self.local(s)
    p = self.project(s)
    g = self.global(s)
    e = self.exernal(s) 
    return PuppetHiera::local_override?(s) if File.exist?(l)
    return PuppetHiera::project_override?(s) if File.exist?(p)
    return PuppetHiera::global_override?(s) if !Vuppeteer::external? && File.exist?(g)
    return PuppetHiera::external_override?(s) if !Vuppeteer::external? && File.exist?(e)
    return false
  end

end