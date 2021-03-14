## 
# Encapsulates host side Git repo management for MrRogers
#

module Repos
  extend self
  
  @initialized = false
  @host_repo_path = 'local-dev.repos'

  def self.setup(repos)
    self._init() if !@initialized
    return if repos.nil?
    Vuppeteer::say("Notice: Updating local project repos...", 'prep')
    MrUtils::enforce_enumerable(repos).each() do |r|
      r_alias = nil #TODO consolidate this pattern with module directive parsing
      if (r.include?(' AS '))
        r_parts = r.split(' AS ')
        r_uri = r_parts[0].strip
        r_alias = r_parts[1].strip
      else 
        r_uri = r
        r_alias = nil
      end
      no_alias_warning = 'Warning: Multiple souces specified for a repo, but no alias is set. This can lead to unpredictable behavior: Always use the AS directive with OR.'
      if (r_uri.include?(' OR '))
        Vuppeteer::say(no_alias_warning, 'prep')  if !r_alias
        r_for = r_alias ? " for repo #{r_alias}" : ''
        r_parts = r_uri.split(' OR ')
        r_parts.each() do |p|
          if ( self.remote_repo_uri(p) || File.exist?(p)) #TODO NOTE, for now we don't test remote repos (e.g. 40X errors)
            Vuppeteer::say("Notice: Selecting #{p} from #{r_parts.to_s}#{r_for}", 'prep')
            r_uri = p
            r_alias = self.repo_project_name(p) if !r_alias
            break
          end
        end
        if (r_uri.include?(' OR ')) 
          Vuppeteer::say("Error: no options from #{r_parts.to_s}#{r_for} found... defaulting to first option (which may not exist???)", 'prep')
          r_uri = r_parts[0]
          r_alias = self.repo_project_name(r_uri) if !r_alias
        end
      else
        r_alias = self.repo_project_name(r_uri) if !r_alias
      end
      Vuppeteer::say("project repos: #{r_uri} > #{r_alias}", 'prep')
      project_repo_path = "#{Mr::active_path()}/#{self.host_repo_path()}/project_repos/#{r_alias}"
      FileManager::path_ensure(project_repo_path, FileManager::allow_dir_creation?)
      if (!self.remote_repo_uri?(r_uri))
        #TODO add a setting to allow updaing of local repos?
        #Vuppeteer::perform_host_commands(["git clone #{self.secure_repo_uri(r)} #{project_repo_path}"])
        Vuppeteer::perform_host_commands([
          {cmd: "rm -Rf #{project_repo_path}/*", when:'prep'},
          {cmd: "cp -r #{r_uri}/* #{project_repo_path}", when:'prep'}
        ])
        Vuppeteer::say("#{r_uri} project repo, is not managed by mr_rogers (perform pull, branch, ect. manually).", 'prep')
      elsif (self.clean_path?(project_repo_path))
        Vuppeteer::perform_host_commands([
          {cmd:"git clone #{self.secure_repo_uri(r_uri)} #{project_repo_path}"}
        ])
        self.branch(project_repo_path, self.repo_uri_branch(r_uri)) if (self.repo_uri_branch(r_uri) != '')
      elsif (self.repo_path?(project_repo_path)) 
        self.branch(project_repo_path, self.repo_uri_branch(r_uri)) if (self.repo_uri_branch(r_uri) != '')
        Vuppeteer::perform_host_commands([{path: project_repo_path, cmd:'git pull', when:'prep'}])
      else
        Vuppeteer::say("Cannot setup #{r_alias} (#{r_uri} > #{project_repo_path}) project repo, target directory is non-empty, and not a working-copy.", 'prep')
      end
    end
  end

  def self.remote_repo_uri?(repo_uri)
    return repo_uri.start_with?('https://') || repo_uri.start_with?('git@') #TODO generalize this more with a regex...
  end

  def self.host_repo_path()
    self._init() if !@init
    @host_repo_path
  end

  def self.repo_project_name(repo_uri)
    repo_uri = repo_uri.split('#',2)[0] if repo_uri.include?('#')
    from_end = repo_uri.end_with?('.git') ? '.git'.length() + 1 : 1
    # print "\n" + [repo_uri, from_end].to_s + "\n" #TODO #issue-18
    # print [repo_uri[(repo_uri.index('/', 8) + 1)..-from_end].gsub('/','-'), from_end].to_s #TODO #issue-18
    if (repo_uri.start_with?('https://')) 
      repo_uri[(repo_uri.index('/', 8) + 1)..-from_end].gsub('/','-').downcase()
    elsif (repo_uri.start_with?('git@')) #TODO generalize this more with a regex...
      repo_uri[(repo_uri.index(':') + 1)..-from_end].gsub('/','-').downcase()
    else 
      repo_uri[0..-from_end].gsub('../','').gsub('/','-').downcase()
    end
  end

  def self.secure_repo_uri(repo_uri)
    repo_uri = repo_uri.split('#', 2)[0] if repo_uri.include?('#')
    developer = Vuppeteer::get_fact('developer')
    enterprise_uri = Vuppeteer::get_fact('ghe_host')
    enterprise_pat = Vuppeteer::get_fact('ghe_pat')
    git_pat = Vuppeteer::get_fact('git_pat')
    git_developer = Vuppeteer::get_fact('git_developer') || developer #TODO support ghc_developer and ghe_developer
    ent_secure_uri = developer && enterprise_uri && enterprise_pat && repo_uri.index("https://#{enterprise_uri}") == 0
    git_secure_uri = developer && git_pat && repo_uri.index("https://github.com") == 0
    return repo_uri.sub("https://","https://#{developer}:#{enterprise_pat}@") if ent_secure_uri
    return repo_uri.sub("https://","https://#{git_developer}:#{git_pat}@") if git_secure_uri
    repo_uri
  end

  def self.repo_uri_branch(repo_uri)
    return repo_uri.split('#', 2)[1] if repo_uri.include?('#')
    return ''
  end

  def self.branch(repo_path, branch)
    #Vuppeteer::perform_host_commands([{path: repo_path, cmd: "git checkout -b #{branch} origin/#{branch}"}])
    Vuppeteer::perform_host_commands([{path: repo_path, cmd: "git checkout #{branch}", when:'prep'}])
  end

  def self.repo_path?(path)
    File.exist?("#{path}/.git")
  end

  #################################################################
  private
  #################################################################

  def self._init()
    @host_repo_path.gsub!('local-dev', FileManager::localize_token()) if @host_repo_path.include?('local-dev')
    @initialized = true
  end

end