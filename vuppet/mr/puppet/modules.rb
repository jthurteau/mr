## 
# Manages Puppet Modules for Mr
#

module Modules
  extend self

  @module_table = {}
  @module_list = [
    'puppetlabs-postgresql', 
    'puppetlabs-apache', 
    'puppetlabs-mysql',
    'puppetlabs-vcsrepo',
    'puppet-python',
    'puppet-nginx',
  ]
  @commands = {
    'install' => [],
    'dev_sync' => [],
    'remove' => [],
    'additional' => [],
    'status' => [],
    'local_install' => []
  }
  @module_shared_path = '/vagrant/puppet/local-dev.repos/puppet_modules'
  @puppet_module_path = '/etc/puppetlabs/code/environments/production/modules'

  def self.init(modules = nil)
    puppet_file_path = PuppetManager::guest_puppet_path()
    @module_shared_path.sub!('/vagrant/puppet', puppet_file_path) if puppet_file_path
    @module_shared_path.sub!('local-dev.repos', RepoManager::host_repo_path()) if @module_shared_path.include?('local-dev.repos')
    if (modules)
      @module_list = MrUtils::enforce_enumerable(modules)
    else
      Vuppeteer::say('Notice: Using default Puppet Modules','prep')
    end
    Vuppeteer::say('Notice: No Puppet Modules configured','prep') if @module_list.length == 0
  end

  def self.processCommands(version) 
    if (version.nil?)
      @commands['status'].push("echo \"no Puppet version specified for module commands\"")
      return
    end
    no_info_string = 'no module version information available for Puppet'
    @commands['status'].push("echo \"#{no_info_string} #{version}\"") if !@module_table[version]
    @module_list.each do |m|
      m_alias = nil
      if (m.include?(' AS '))
        m_parts = m.split(' AS ')
        m = m_parts[0]
        m_alias = m_parts[1]
      end
      if (m.include?(' OR '))
        m_for = m_alias ? " for module #{m_alias}" : ''
        m_parts = m.split(' OR ')
        #Puppeteer::say("Notice: Scanning options#{m_for} in #{m_parts.to_s}", 'prep')
        m_parts.each() do |p|
          if (File.exist?(p))
            Vuppeteer::say("Notice: Selecting #{p} from #{m_parts.to_s}#{m_for}", 'prep')
            m = p
            break
          end
        end
        if (m.include?(' OR ')) 
          Vuppeteer::say("Error: no options from #{m_parts.to_s}#{m_for} found... defaulting to first option (which may not exist???)", 'prep')
          m = m_parts[0]
        end
      end
      
      if (m.start_with?('https://') || !m_alias.nil?)
        m_name = m.start_with?('https://') ? self.prep_repo_inserts(m) : self.prep_fs_inserts(m)
        m_alias = m_name if m_alias.nil?
 #       Puppeteer::say("debug: module mirror command cp -r #{@module_shared_path}/#{m_name} #{@puppet_module_path}/#{m_alias}")
        commands = [
          "echo \" copying #{@module_shared_path}/#{m_name} to #{@puppet_module_path}/#{m_alias}\"",
          "rm -Rf #{@puppet_module_path}/#{m_alias}",
          "cp -r #{@module_shared_path}/#{m_name} #{@puppet_module_path}/#{m_alias}",
        ]
        self.push_commands(commands,['install', 'dev_sync'])
        @commands['remove'].push("rm -Rf #{@puppet_module_path}/#{m_alias}")
      else
        version_available = @module_table[version]&.has_key?(m)
        @commands['status'].push("echo module #{m} version information unavailable for puppet #{version}") if !version_available
        version_flag = version_available ? " --version #{@module_table[version][m]}" : ''
        @commands['install'].push("puppet module install #{m}#{version_flag}")
        @commands['remove'].push("puppet module uninstall #{m}")
      end
    end
    @commands['additional'].push("puppet config set strict_variables true --section main")
  end

  def self.push_commands(commands, groups)
    groups.each do |g|
      commands.each do |c|
        @commands[g].push(c)
      end
    end
  end

  def self.get_commands(commands)
    output = []
    commands.each do |g|
      @commands[g].each {|cc| output.push(cc)} if @commands.has_key?(g)
    end
    output
  end

  def self.prep_fs_inserts(path)
    #TODO, make sure environments/production/modules exists on remote, that doesn't seem to be guarunteed /etc/puppetlabs/code/..
    @commands['local_install'].push({say:"  mirroring module at #{path}"})
    module_name = File.basename(path) #TODO #issue-18
    #module_source = tokenize parent dirs too for further differentiation when needed
    local_mirror_path = "#{self.host_module_path()}/#{module_name}"
    FileManager::path_ensure(local_mirror_path, Puppeteer::allow_dir_creation?)
    if (FileManager::clean_path?(local_mirror_path))
      # print(["cp -r #{path}/* #{local_mirror_path}"].to_s)
      # exit
      @commands['local_install'].push("cp -r #{path}/* #{local_mirror_path}")
      @commands['local_install'].push("touch #{local_mirror_path}/.mr_lock")
    elsif (FileManager::managed_path?(local_mirror_path)) 
      @commands['local_install'].push("rm -Rf #{local_mirror_path}/*")
      @commands['local_install'].push("touch #{local_mirror_path}/.mr_lock")
      @commands['local_install'].push("cp -r #{path}/* #{local_mirror_path}")
    else
      @commands['local_install'].push({say:"Cannot setup #{path} puppet module, target directory is non-empty, and not managable."})
    end
    module_name
  end

  def self.prep_repo_inserts(uri) #NOTE use puppet-sync provisioner to update these
    auth_uri = RepoManager::secure_repo_uri(uri)
    @commands['local_install'].push({say:"retreiving #{uri}"})
    module_name = uri[(uri.index('/', 8) + 1)..-5].gsub('/','-') #TODO #issue-18
    #module_source = tokenize host name too for further differentiation when needed
    module_repo_path = "#{self.host_module_path()}/#{module_name}"
    FileManager::path_ensure(module_repo_path, Puppeteer::allow_dir_creation?)
    if (RepoManager::clean_path?(module_repo_path))
      @commands['local_install'].push("git clone #{auth_uri} #{module_repo_path}")
    elsif (RepoManager::repo_path?(module_repo_path)) 
      @commands['local_install'].push({path: module_repo_path, cmd:"git pull"})
    else
      @commands['local_install'].push({say:"Cannot setup #{uri} puppet module, target directory is non-empty, and not a working-copy."})
    end
    module_name
  end

  def self.set_versions(version_data)
    @module_table = version_data
  end

  def self.host_module_path()
    "#{Mr::active_path()}/#{RepoManager::host_repo_path()}/puppet_modules"
  end

  def self.list()
    @module_list
  end

#################################################################
  private
#################################################################



end