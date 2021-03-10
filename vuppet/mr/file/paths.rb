## 
# Encapsulates host file management for Mp
#

module FilePaths
  extend self

  @paths = {
    root:  { set: false, label: 'Project Root', match: ['.'] }, #path relative to the Vagrantfile
    read:  { set: false, label: 'Read Path'   , match: ['..', '~/.mr'] }, #paths relative to the project root
    write: { set: false, label: 'Write Path', match: ['vuppet'] }, #paths relative to the project root
  }

  def self.init(root = nil)
    self._init(:root, root) if !@paths[:root][:set]
    @paths.each do |k, p|
      p[:set] = true
    end
    @paths[:read][:match].each_index do |i|
      p = @paths[:read][:match][i]
      next if p.start_with?('~/')
      pa = File.absolute_path(p)
      @paths[:read][:match][i] = pa if pa != p
    end
    @paths[:write][:match].each_index do |i|
      p = @paths[:write][:match][i]
      next if p.start_with?('~/')
      pa = File.absolute_path(p)
      @paths[:write][:match][i] = pa if pa != p
    end
  end

  def self.project_root(new_path = nil)
    self._init(:root, new_path) if new_path
    @paths[:root][:match]
  end

  def self.read_path(new_path = nil)
    self._init(:read, new_path) if new_path
    @paths[:read][:match]
  end

  def self.write_path(new_path = nil)
    self._init(:write, new_path) if new_path
    @paths[:write][:match]
  end

  def self.may_write?(path)
    #(Vuppeteer::external? || !FilePaths::in?(path, Mr::path)) && FilePaths::in?(path, Mr::active_path)
    @paths[:write][:match].each do |p|
      return true if self.in?(path, p)
    end
    false
  end

  def self.clean?(path)
    Dir.empty?(path)
  end

  #TODO def self.manage(path)

  def self.managed?(path)
    File.exist?("#{path}/.mr_lock")
  end

  def self.clear(path)
    if (!path.start_with?(Mr::active_path()))
      Puppeteer::say("Warning: Unable to clear path #{path}, not in active path.", 'prep')
      return false
    end
    FileUtils.rm_r(Dir.glob("#{path}/*"))
  end

  def self.temp_path()
    "#{FileManager::localize_token}.tmp/"
  end

  def self.absolute?(path)
    return path == File.absolute_path(path)
  end

  def self.in?(child, parent, inclusive = true)
    #print([__FILE__,__LINE__,child,parent,inclusive].to_s)
    c = File.absolute_path(child)
    c += c.end_with?('/') ? '' : '/'
    p = File.absolute_path(parent)
    p += p.end_with?('/') ? '' : '/'
    return c.start_with?(p) && (inclusive || c != p)
  end

  def self.ensure(path, create = false, verbose = true)
    if (!self.may_write?(path) && create)
      can_write = @paths[:write][:match].to_s
      where = verbose ? ": #{path} not in #{can_write}" : ''
      Vuppeteer::shutdown("attempting to create paths outside of allowed write path#{where}.\n" , -1)
    end
    path_components = path ? path.split('/') : []
    confirmed_path = ''
    path_components.each do |p|
      current_path = "#{confirmed_path}/#{p}"
      initial_skip = '' == confirmed_path && current_path.end_with?(':')
      if (!initial_skip && !File.directory?(current_path))
        if (create && self.may_write?(current_path))
          verbose_string = "attempting to create directory #{p} in #{confirmed_path}"
          Vuppeteer::say(verbose.class == TrueClass ? verbose_string : verbose, 'prep') if verbose
          Dir.mkdir(current_path, 0755)
          confirmed_path += initial_skip ? p : "/#{p}"
        else
          Vuppeteer::shutdown("directory #{p} does not exist in #{confirmed_path}\n", -1)
        end
      else
        confirmed_path += initial_skip ? p : "/#{p}"
      end
    end
    return confirmed_path
  end

  def self.fact(fact)
    self._x_path(fact, 'facts')
  end

  def self.manifest(manifest)
    self._x_path(manifest, 'manifests')
  end

  def self.bash(script)
    self._x_path(script, 'bash')
  end

  def self.template(script)
    self._x_path(script, 'templates')
  end

  def self.local(file, type)
    "#{Mr::active_path()}/#{FileManager::localize_token}.#{type}/#{file}"
  end

  def self.project(file, type)
    "#{Mr::active_path()}/#{type}/#{file}"
  end

  def self.global(file, type)
    "#{Mr::active_path()}/global.#{type}/#{file}"
  end

  def self.external(file, type)
    Vuppeteer::external? ? "#{Vuppeteer::external_path}/#{type}/#{file}" : nil
  end

#################################################################
  private
#################################################################

  def self._init(p, v)
    p = p.to_sym
    raise 'Unrecognized path designation ' + (p.to_s) + ' called for initialization.' if !@paths.has_key?(p)
    raise @paths[p][:label] + ' can only be set once.' if @paths[p][:set]
    @paths[p][:match] = MrUtils::enforce_enumerable(v)
    @paths[p][:set] = true
  end

  def self._x_path(file, type)
    e = "#{Vuppeteer::external_path()}/#{type}"
    l = "#{Mr::active_path()}/#{FileManager::localize_token}.#{type}"
    p = "#{Mr::active_path()}/#{type}"
    g = "#{Mr::active_path()}/global.#{type}" #TODO make this prefix non-staticly defined
    return l if File.readable?("#{l}/#{file}")
    return g if !Vuppeteer::external? && File.readable?("#{g}/#{file}") && !File.readable?("#{p}/#{file}")
    return e if Vuppeteer::external? && File.readable?("#{e}/#{file}") && !File.readable?("#{p}/#{file}")
    p
  end

end