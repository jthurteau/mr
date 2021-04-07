## 
# Encapsulates host file management for Mp
#

module Paths
  extend self

  @paths = {
    root:  { set: false, label: 'Project Root', match: ['.'] }, #path relative to the Vagrantfile
    read:  { set: false, label: 'Read Path'   , match: ['..', '~/.mr'] }, #paths relative to the project root
    write: { set: false, label: 'Write Path', match: ['vuppet'] }, #paths relative to the project root
  }

  @current_root = 0 #TODO someday we may want to support multiple roots?

  def self.init(root = nil)
    self._init(:root, root) if !@paths[:root][:set]
    @paths.each do |k, p|
      p[:set] = true
    end
    @paths[:root][:match][@current_root] = File.absolute_path(@paths[:root][:match][@current_root])
    @paths[:read][:match].each_index do |i|
      p = @paths[:read][:match][i]
      next if p.start_with?('~/')
      pa = File.absolute_path(p, @paths[:root][:match][@current_root])
      @paths[:read][:match][i] = pa if pa != p
    end
    @paths[:write][:match].each_index do |i|
      p = @paths[:write][:match][i]
      next if p.start_with?('~/')
      pa = File.absolute_path(p, @paths[:root][:match][@current_root])
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
    @paths[:write][:match].each do |p|
      return true if self.in?(path, p)
    end
    false
  end

  def self.may_read?(path)
    @paths[:read][:match].each do |p|
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

  def self.clear!(path)
    if (!path.start_with?(Mr::active_path()))
      Vuppeteer::say("Warning: Unable to clear path #{path}, not in active path.", :prep)
      return false
    elsif (!self.may_write?(path))
      Vuppeteer::say("Warning: Unable to clear path #{path}, not in write path.", :prep)
      return false
    end
    FileUtils.rm_r(Dir.glob("#{path}/*"))
  end

  def self.absolute?(path)
    return path == File.absolute_path(path)
  end

  def self.in?(child, parent, inclusive = true)
    #Vuppeteer::trace(child,parent,inclusive)
    c = File.absolute_path(child)
    c += c.end_with?('/') ? '' : '/'
    p = File.absolute_path(self.expand(parent))
    p += p.end_with?('/') ? '' : '/'
    return c.start_with?(p) && (inclusive || c != p)
  end

  def self.expand(path)
    return File.expand_path(path) if path.start_with?('~')
    path
  end

  def self.ensure(path, create = false, verbose = false)
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
          Vuppeteer::say(verbose.is_a?(TrueClass) ? verbose_string : verbose, :prep) if verbose && Vuppeteer::enabled?(:verbose)
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

  def self.temp()
    "#{FileManager::localize_token}.tmp"
  end

  def self.x_path(type, file = nil)
    file = file ? "/#{file}" : ''
    l = self.local(type)
    p = self.project(type)
    g = self.global(type) #TODO make this prefix non-staticly defined
    e = self.external(type)
    return l if File.readable?("#{l}#{file}")
    return p if File.readable?("#{p}#{file}")
    return g if !Vuppeteer::external? && File.readable?("#{g}#{file}")
    return e if Vuppeteer::external? && File.readable?("#{e}#{file}")
    nil
  end

  def self.local(type, file = nil)
    file = file ? "/#{file}" : ''
    "#{Mr::active_path()}/#{FileManager::localize_token}.#{type}#{file}"
  end

  def self.project(type, file = nil)
    file = file ? "/#{file}" : ''
    "#{Mr::active_path()}/#{type}#{file}"
  end

  def self.global(type, file = nil)
    file = file ? "/#{file}" : ''
    "#{Mr::active_path()}/global.#{type}#{file}"
  end

  def self.external(type, file = nil)
    file = file ? "/#{file}" : ''
    Vuppeteer::external? ? "#{Vuppeteer::external_path}/#{type}#{file}" : nil
  end

  def self.type(path)
    return 'external' if Vuppeteer::external? && path.start_with?("#{Vuppeteer::external_path}")
    return 'global' if !Vuppeteer::external? && path.start_with?("#{Mr::active_path()}/global.")
    return 'local' if path.start_with?("#{Mr::active_path()}/#{FileManager::localize_token}.")
    return 'project' if path.start_with?("#{Mr::active_path()}/")
    return 'unknown'
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

end