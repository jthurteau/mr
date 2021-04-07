## 
# Manages Puppet Modules for Mr
#

module Modules
  extend self

  @module_table = {}
  @module_list = {
    default:[
      'puppetlabs-postgresql', 
      'puppetlabs-apache', 
      'puppetlabs-mysql',
      'puppetlabs-vcsrepo',
      'puppet-python',
      'puppet-nginx',
    ],
  }
  @commands = {
    default: {
      'install' => [],
      'dev_sync' => [],
      'remove' => [],
      'additional' => [],
      'status' => [],
      'local_install' => []
    },
    null: {
      'install' => [],
      'dev_sync' => [],
      'remove' => [],
      'additional' => [],
      'status' => [],
      'local_install' => []
    }
  }
  @module_shared_path = 'vuppet/#{ldr}/puppet_modules'
  @puppet_module_path = '/etc/puppetlabs/code/environments/production/modules'

  def self.init(modules = nil)
    if (modules)
      @module_list[:default] = MrUtils::enforce_enumerable(modules)
    else
      Vuppeteer::say('Notice: Using default Puppet Modules', :prep)
    end
    Vuppeteer::say('Notice: No Puppet Modules configured', :prep) if @module_list[:default].length == 0
    @puppet_module_path = '/etc/puppet/modules' if !ElManager::is_it?()
  end

  def self.processCommands(group = :default) 
    local_host_repos = FileManager::host_repo_path()
    module_path = PuppetManager::guest_path(@module_shared_path, group)
    module_shared_path = module_path.sub('#{ldr}', local_host_repos)
    #Vuppeteer::trace('module version commands',group, module_shared_path)
    if (group.nil?)
      @commands[:null]['status'].push("echo \"Notice: no group specified for module commands\"")
      return
    end
    if (!@module_list.has_key?(group))
      @commands[:null]['status'].push("echo \"Warning: no matching group for requested module commands, using default settings\"")
      group = :default
    end
    
    group_string = group.to_s #TODO 'Puppet V if numeric/version otherwise VM Group'
    no_info_string = 'no module version information available for Puppet'
    group_version_lookup = group
    if (!@module_table.has_key?(group))
      @commands[:null]['status'].push("echo \"Warning: no matching group for requested module versions, using default puppet_version settings\"")
      group_version_lookup = PuppetManager::version()
      group_version_string = group_version_lookup
    end
    #Vuppeteer::trace('module versions', group_version_lookup)
    @commands[group]['status'].push("echo \"#{no_info_string} #{group_version_string}\"") if !@module_table.has_key?(group_version_lookup)

    modules = @module_list.has_key?(group) ? @module_list[group] : @module_list[:default]
    modules.each do |m|
      m_alias = nil
      if (m.include?(' AS '))
        m_parts = m.split(' AS ')
        m = m_parts[0]
        m_alias = m_parts[1]
      end
      if (m.include?(' OR '))
        m_for = m_alias ? " for module #{m_alias}" : ''
        m_parts = m.split(' OR ')
        #Vuppeteer::say("Notice: Scanning options#{m_for} in #{m_parts.to_s}", :prep)
        m_parts.each() do |p|
          if (File.exist?(p))
            Vuppeteer::say("Notice: Selecting #{p} from #{m_parts.to_s}#{m_for}", :prep)
            m = p
            break
          end
        end
        if (m.include?(' OR ')) 
          Vuppeteer::say("Error: no options from #{m_parts.to_s}#{m_for} found... defaulting to first option (which probably doesn't exist?!?)", :prep)
          m = m_parts[0]
        end
      end
      
      if (m.start_with?('https://') || !m_alias.nil?)
        m_name = m.start_with?('https://') ? self.prep_repo_inserts(m) : self.prep_fs_inserts(m)
        m_alias = m_name if m_alias.nil?
 #       Vuppeteer::say("debug: module mirror command cp -r #{module_shared_path}/#{m_name} #{@puppet_module_path}/#{m_alias}")
        commands = [
          "echo \" copying #{module_shared_path}/#{m_name} to #{@puppet_module_path}/#{m_alias}\"",
          "rm -Rf #{@puppet_module_path}/#{m_alias}",
          "cp -r #{module_shared_path}/#{m_name} #{@puppet_module_path}/#{m_alias}",
        ]
        self.push_commands(commands,['install', 'dev_sync'], group)
        @commands[group]['remove'].push("rm -Rf #{@puppet_module_path}/#{m_alias}")
      else
        version_available = @module_table.has_key?(group_version_lookup) && @module_table[group_version_lookup].has_key?(m)
        @commands[group]['status'].push("echo module #{m} version information unavailable for puppet #{group_version_string}") if !version_available
        version_flag = version_available ? " --version #{@module_table[group_version_lookup][m]}" : ''
        #Vuppeteer::trace('command trace', group, group_version_lookup, m, version_flag)
        @commands[group]['install'].push("puppet module install #{m}#{version_flag}")
        @commands[group]['remove'].push("puppet module uninstall #{m}") #TODO this doesn't handle dependencies also installed, so it needs to be re-written
      end
    end
    @commands[group]['additional'].push("puppet config set strict_variables true --section main")
  end

  def self.push_commands(commands, command_groups, vm_group = :default)
    command_groups.each do |g|
      commands.each do |c|
        @commands[vm_group][g].push(c)
      end
    end
  end

  def self.get_commands(commands, vm_group = :default)
    output = []
    commands.each do |g|
      @commands[:null][g].each {|cc| output.push(cc)} if @commands[:null].has_key?(g)
      @commands[vm_group][g].each {|cc| output.push(cc)} if @commands[vm_group].has_key?(g)
    end
    output
  end

  def self.prep_fs_inserts(path, vm_group = :default)
    #TODO, make sure environments/production/modules exists on remote, that doesn't seem to be guarunteed /etc/puppetlabs/code/..
    @commands[vm_group]['local_install'].push({say:"  mirroring module at #{path}"})
    module_name = File.basename(path) #TODO #issue-18
    #module_source = tokenize parent dirs too for further differentiation when needed
    local_mirror_path = "#{self.host_module_path()}/#{module_name}"
    FileManager::path_ensure(local_mirror_path, FileManager::allow_dir_creation?)
    if (FileManager::clean_path?(local_mirror_path)) #TODO move this into FileManager? Paths?
      # Vuppeteer::trace("cp -r #{path}/* #{local_mirror_path}")
      # exit
      @commands[vm_group]['local_install'].push("cp -r #{path}/* #{local_mirror_path}")
      @commands[vm_group]['local_install'].push("touch #{local_mirror_path}/.mr_lock")
    elsif (FileManager::managed_path?(local_mirror_path)) 
      @commands[vm_group]['local_install'].push("rm -Rf #{local_mirror_path}/*")
      @commands[vm_group]['local_install'].push("touch #{local_mirror_path}/.mr_lock")
      @commands[vm_group]['local_install'].push("cp -r #{path}/* #{local_mirror_path}")
    else
      @commands[vm_group]['local_install'].push({say:"Cannot setup #{path} puppet module, target directory is non-empty, and not managable."})
    end
    module_name
  end

  def self.prep_repo_inserts(uri, vm_group = :default) #NOTE use puppet-sync provisioner to update these
    auth_uri = FileManager::secure_repo_uri(uri)
    @commands[vm_group]['local_install'].push({say:"retreiving #{uri}"})
    module_name = uri[(uri.index('/', 8) + 1)..-5].gsub('/','-') #TODO #issue-18
    #module_source = tokenize host name too for further differentiation when needed
    module_repo_path = "#{self.host_module_path()}/#{module_name}"
    FileManager::path_ensure(module_repo_path, FileManager::allow_dir_creation?)
    if (FileManager::clean_path?(module_repo_path))
      @commands[vm_group]['local_install'].push("git clone #{auth_uri} #{module_repo_path}")
    elsif (FileManager::repo_path?(module_repo_path)) 
      @commands[vm_group]['local_install'].push({path: module_repo_path, cmd:"git pull"})
    else
      @commands[vm_group]['local_install'].push({say:"Cannot setup #{uri} puppet module, target directory is non-empty, and not a working-copy."})
    end
    module_name
  end

  def self.set_versions(version_data, group = nil)
    return if !version_data.is_a?(Hash)
    @module_table = version_data.merge(@module_table) if group.nil?
    @module_table[group] = version_data if !group.nil?
  end

  def self.host_module_path()
    "#{Mr::active_path()}/#{FileManager::host_repo_path}/puppet_modules"
  end

  def self.list()
    @module_list
  end

#################################################################
  private
#################################################################



end