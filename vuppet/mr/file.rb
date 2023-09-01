## 
# Encapsulates host file management for Mr
#

module FileManager
  extend self
  
  require 'yaml'
  require_relative 'file/paths'
  require_relative 'file/repos'
  #TODO require_relative 'file/cache'

  @initialized = false
  @localize_token = 'local-dev'
  @override_token = 'example'

  @allow_host_dir_creation = true

  def self.init(root = nil)
    return if @initialized
    self.localize_token(Vuppeteer::get_fact('localize_token'))
    self.override_token(Vuppeteer::get_fact('override_token'))
    Paths::project_root(Vuppeteer::get_fact('host_root_path')) #NOTE if this is nil, the value in root param prevails
    Paths::read_path(Vuppeteer::get_fact('host_allowed_read_path')) 
    Paths::write_path(Vuppeteer::get_fact('host_allowed_write_path'))
    Paths::init(root)
    @initialized = true
  end

  def self.localize_token(new_token = nil)
    @localize_token = new_token if (!@initialized && new_token)
    @localize_token
  end

  def self.override_token(new_token = nil)
    @override_token = new_token if (!@initialized && new_token)
    @override_token
  end

  def self.allow_dir_creation?
    return @allow_host_dir_creation
  end

  def self.path_ensure(path, create = false, verbose = false)
    Paths::ensure(path, create, verbose)
  end

  def self.path(w, p = nil, f = nil)
    case w
    when :temp
      return Paths::temp()
    when :fact
      return Paths::x_path('facts', p)
    when :hiera
      return Paths::x_path('hiera', p)
    when :manifest
      return Paths::x_path('manifests', p)
    when :bash
      return Paths::x_path('bash', p)
    when :template
      return Paths::x_path('templates', p)
    when :global
      return p.nil? ? false : Paths::global(p, f)
    when :local
      return p.nil? ? false : Paths::local(p, f)
    when :project
      return p.nil? ? false : Paths::project(p, f)
    when :external
      return p.nil? ? false : Paths::external(p, f)
    end
    false
  end

  def self.path_type(p)
    Paths::type(p)
  end

  def self.first_match(files)
    files.each() do |f|
      return f if File.exist?(f)
    end
    nil
  end

  def self.tokened_file(path, token)
    token = MrUtils::enforce_enumerable(token)
    first_token = token[0]
    f = nil
    #Vuppeteer::trace(path, token,File.file?(path))
    #exit
    if !File.file?(path)
        f = File.new(path, 'w+')
        f.write("# #{first_token}#{$/}")
    else
      f = File.new(path, 'a+')
      token.each do |t|
        f.rewind
        return f if f.readline.start_with?("# #{t}")
      end
      f.close
      f = nil
    end
    f
  end

  def self.scan(file, search, comments_only = true)
    return [] if !File.file?(file)
    f = File.new(file, 'r')
    lines =  []
    f.rewind
    f.each() do |l|
      candidate = !comments_only || l.lstrip().start_with?('#')
      match = candidate && l.split('#', 2).last().lstrip().start_with?(search)
      lines.push(l.split(search, 2).last) if match
      #Vuppeteer::say([file, search, l, l.split('#',2).last().lstrip(), l.split('#', 2).last().lstrip().start_with?(search)].to_s) if candidate
    end
    f.close
    lines
  end

  def self.facet_split(source = nil)
    s = MrUtils::splitter
    source.nil? ? s : (source.include?(s) ? source.split(s, 2) : [source])
  end

  ##
  # loads a yaml file, if it exists and has hash keys
  def self.load_fact_yaml(path, flag = :critical)
    critical = flag.is_a?(TrueClass) || flag == :critical || (flag.is_a?(Array) && flag.include?(:critical))
    #preserve_sym_keys = flag == :preserve_keys || (flag.is_a?(Array) && flag.include?(:preserve_keys))
    parts = self.facet_split(path)
    path = parts[0].end_with?('.yaml') ? parts[0] : "#{parts[0]}.yaml"
    #Vuppeteer::trace('FileManager::load_fact_yaml', path)
    path = Mr::path(path) if !Paths::absolute?(path) 
    #Vuppeteer::trace('FileManager::load_fact_yaml', path)
    facet = parts.length > 1  && parts[1] != '' ? parts[1] : nil
    # Vuppeteer::trace(path,facet,critical)
    if (!File.exist?(path))
      VuppeteerUtils::meditate("Facts \"#{path}\" not available", critical, :prep)
      return nil
    end
    begin
      y = YAML.load_file(path)
    rescue SystemCallError => e #TODO handle yaml parse errors
      VuppeteerUtils::meditate("Unable to load facts in \"#{path}\"", critical, :prep)
    end
    VuppeteerUtils::meditate("Empty facts in \"#{path}\"", critical, :prep) if (y.nil?)
    VuppeteerUtils::meditate("Invalid facts in \"#{path}\"", critical, :prep) if (!y.nil? && !y.is_a?(Hash))
    # print([y.to_s])
    # x = MrUtils::string_keys(y) if !preserve_sym_keys && y.is_a?(Hash)
    y.is_a?(Hash) ? (facet.nil? ? y : (y.has_key?(facet) ? y[facet] : nil) ) : nil
  end

  def self.save_yaml(path, data, backup = false)
    self._backup(path) if backup
    f = File.new(path, 'a+')
    f.rewind
    if (!f.eof? && f.readline.start_with?("# @protected"))
      f.close
      Vuppeteer::say("Error: attempted to save to protected config file #{path}", :prep);
      return false
    end
    begin
      f.truncate(0)
      o = YAML.dump(data)
      tag = "# Mr managed config file (manual editing not recommended)"
      wrapped = (o.start_with?('---') ? '' : "---\n") + o + (o.end_with?('...') ? '' : "\n...")
      f.write("#{tag}\n#{wrapped}")
      f.close
    rescue => e
      Vuppeteer::say("Error: failed to write to config file #{path} #{e.to_s}", :prep);
      f.close
      return false
    end
    return true
  end

  def self.may?(operation, path)
    case operation
    when :write
      return Paths::may_write?(path)
    when :read
      return Paths::may_read?(path)
    end
    false
  end

  def fs_view()
    return Files.new().view()
  end

  #################################################################
  # delegations
  #################################################################

  def self.bash(s, v = nil)
    VuppeteerUtils::script(s, v)
  end

  def self.clear!(p)
    Paths::clear!(p)
  end

  def self.absolute?(p)
    Paths::absolute?(p)
  end

  #################################################################
  # gateway methods
  #################################################################

  def self.secure_repo_uri(u)
    Repos::secure_repo_uri(u)
  end

  def self.clean_path?(p)
    Paths::clean?(p)
  end

  def self.repo_path?(p)
    Repos::path_is?(p)
  end

  def self.host_repo_path
    Repos::host_repo_path()
  end

  def self.copy_unique(from, to)
    self._copy_unique(from, to) #TODO this has been moved around a lot, so clean up?
  end

  def self.managed_path?(p)
    Paths::managed?(p)
  end

  #################################################################
    private
  #################################################################

  def self._copy_unique(from, to, max_back = 2)
    create_files = []
    use_base = false
    if !from.class.include?(Enumerable)
      if File.directory?(from)
        use_base = true
        from_path = from
        f = Dir.children(from)
        from = []
        f.each do |c| #TODO there is definately a more rubic way to do this
          from.push("#{from_path}/#{c}")
        end
      else
        from = [from]
      end
    end
    #to += '/' if !to.end_with?('/')
    from.each do |f|
      ext = File.extname(f)
      base = File.basename(f,'.*')
      rest = File.dirname(f).split('/').last(max_back)
      unique = use_base ? ".#{base}" : ''
      while (File.exist?("#{to}#{unique}#{ext}"))
        additional = rest.pop()
        additional = 'x' if additional.nil?
        unique += ".#{additional}"
      end
      #Vuppeteer.say("normally I would cp #{f} to #{to}#{unique}#{ext}")
      FileUtils.cp_r(f,"#{to}#{unique}#{ext}")
      to_base = File.basename(to)
      create_files.push("#{to_base}#{unique}#{ext}")
    end
    create_files
  end

  def self._backup(path)
    unique = '' #TODO this is quick and dirty
    if (File.exist?("#{path}.bak")) 
      unique = time.now.to_i #Not intended to be run in fast succession anyway
    end
    FileUtils.cp(path, "#{path}.bak#{unique}")
  end

  class Files

    def view() #TODO #1.0.0 this needs to know which VM it is in multi-vm
      return binding()
    end

    def localize_token()
      return FileManager::localize_token()
    end

    def puppet_guest_path(p = nil, v = nil)
      PuppetManager::guest_path(p, v)
    end

    def shared_guest_path(v = nil)
      PuppetManager::guest_root(v)
    end

  end

end