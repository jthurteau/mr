## 
# Encapsulates host file management for Mr
#

module FileManager
  extend self

  require_relative 'file/paths'
  require_relative 'file/mirror'
  require_relative 'file/erbash'
  require_relative 'file/repos'

  @initialized = false
  @localize_token = 'local-dev'
  @override_token = 'example'

  @allow_host_dir_creation = true

  #TODO @loaded_files = {}

  def self.init(root = nil)
    return if @initialized
    self.localize_token(Vuppeteer::get_fact('localize_token'))
    self.override_token(Vuppeteer::get_fact('override_token'))
    FilePaths::project_root(Vuppeteer::get_fact('host_root_path')) 
    FilePaths::read_path(Vuppeteer::get_fact('host_allowed_read_path')) 
    FilePaths::write_path(Vuppeteer::get_fact('host_allowed_write_path'))
    FilePaths::init(root)
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

  def self.path_ensure(path, create = false, verbose = true)
    FilePaths::ensure(path, create, verbose)
  end

  def self.path(w, p = nil, f = nil)
    case w
    when :temp
      return FilePaths::temp()
    when :fact
      return FilePaths::x_path('facts', p)
      def self.manifest(manifest)
        self._x_path(manifest, 'manifests')
      end
    
      def self.bash(script)
        self._x_path(script, 'bash')
      end
    
      def self.template(script)
        self._x_path(script, 'templates')
      end
    
      def self.hiera(script)
        self._x_path(script, 'hiera')
      end
    when :hiera
      return p.nil? ? false : FilePaths::hiera(p)
    when :manifest
      return p.nil? ? false : FilePaths::manifest(p)
    when :bash
      return p.nil? ? false : FilePaths::bash(p)
    when :template
      return p.nil? ? false : FilePaths::template(p)
    when :global
      return p.nil? ? false : FilePaths::global(p, f)
    when :local
      return p.nil? ? false : FilePaths::local(p, f)
    when :project
      return p.nil? ? false : FilePaths::project(p, f)
    when :external
      return p.nil? ? false : FilePaths::external(p, f)
    end
    false
  end

  def self.first_match(files)
    files.each() do |f|
      return f if File.exist?(f)
    end
    nil
  end

  def self.tokened_file(path, token)
    token = Puppeteer::enforce_enumerable(token)
    first_token = token[0]
    f = nil
    #print([path, token,File.file?(path)].to_s)
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
      #Puppeteer::say([file, search, l, l.split('#',2).last().lstrip(), l.split('#', 2).last().lstrip().start_with?(search)].to_s) if candidate
    end
    f.close
    lines
  end

  ##
  # loads a yaml file, if it exists and has hash keys
  def self.load_fact_yaml(path, critical = true)
    if (path.include?('::'))
      parts = path.split('::', 2)
      fact = parts.length > 1  && parts[1] != '' ? parts[1] : nil
      path = parts[0]
    else
      fact = nil 
    end
    if (!File.exist?(path))
      MrUtils::meditate("facts \"#{path}\" not available", critical, 'prep')
      return nil
    end
    begin
      y = YAML.load_file(path)
    rescue SystemCallError => e #TODO handle yaml parse errors
      MrUtils::meditate("unable to load facts in \"#{path}\"", critical, 'prep')
    end
    MrUtils::meditate("empty facts in \"#{path}\"", critical, 'prep') if (y.nil?)
    MrUtils::meditate("invalid facts in \"#{path}\"", critical, 'prep') if (!y.nil? && y.class != Hash)
    y.class == Hash ? (fact.nil? ? y : (y.has_key?(fact) ? y[fact] : nil) ) : nil
  end

  # def self.load_config_yaml(path, description)
  #   #rescueable = [SystemCallError, Psych::SyntaxError]
  #   unavailable_file_text = "#{description} configurations unavailable"
  #   unparsable_file_text = "#{description} configurations unparsable"
  #   external_file_text = "Using external #{description} configurations."
  #   config = nil
  #   begin
  #     config = YAML.load_file(path) if File.exist?(path)
  #   rescue SystemCallError => e
  #     if !Puppeteer::external?
  #       Puppeteer::say("Warning: #{unavailable_file_text}" ,'prep')
  #       return config
  #     end
  #   rescue Psych::SyntaxError => e
  #     if !Puppeteer::external?
  #       Puppeteer::say("Warning: #{unparsable_file_text}, #{e.to_s}" ,'prep')
  #       return config
  #    end
  #   end   
  #   return config if config || !Puppeteer::external?
  #   Puppeteer::say(external_file_text ,'prep')
  #   external_path = Mr::path(path)
  #   begin
  #     config = YAML.load_file(external_path)
  #   rescue SystemCallError => e
  #     Puppeteer::say("Warning: #{unavailable_file_text}" ,'prep')
  #     config = {}
  #   rescue Psych::SyntaxError => e
  #     Puppeteer::say("Warning: #{unparsable_file_text}, #{e.to_s}" ,'prep')
  #     return config
  #   end
  #   config
  # end

  def self.save_yaml(path, data, backup = false)
    self._backup(path) if backup
    f = File.new(path, 'a+')
    f.rewind
    if (!f.eof? && f.readline.start_with?("# @protected"))
      f.close
      Puppeteer::say("Error: attempted to save to protected config file #{path}", 'prep');
      return false
    end
    begin
      f.truncate(0)
      o = YAML.dump(data)
      tag = "# MrRogers managed config file (manual editing not recommended)"
      wrapped = (o.start_with?('---') ? '' : "---\n") + o + (o.end_with?('...') ? '' : "\n...")
      f.write("#{tag}\n#{wrapped}")
      f.close
    rescue => e
      Puppeteer::say("Error: failed to write to config file #{path} #{e.to_s}", 'prep');
      f.close
      return false
    end
    return true
  end

  def self.may?(operation, path)
    case operation
    when :write
      return FilePaths::may_write?(path)
    when :read
      return FilePaths::may_read?(path)
    end
    false
  end

  def fs_view()
    return Files.new().view()
  end

#################################################################
  private
#################################################################

  def self._backup(path)
    unique = '' #TODO this is quick and dirty
    if (File.exist?("#{path}.bak")) 
      unique = time.now.to_i #Not intended to be run in fast succession anyway
    end
    FileUtils.cp(path, "#{path}.bak#{unique}")
  end

  class Files

    def view()
      return binding()
    end

    def puppet_file_path()
      PuppetManager::guest_puppet_path()
    end

    def localize_token()
      return FileManager::localize_token()
    end
  end

end