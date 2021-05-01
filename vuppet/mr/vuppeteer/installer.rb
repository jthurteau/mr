## 
# Encapsulates installer management for mr
#

module Installer
  extend self

  @install_files = [
    'mr.rb', 
    'mr',
    '+el.yaml',
    '+puppet.yaml',
    '+vagrant.yaml',
    '+local-dev.example.vuppeteer.yaml',
    '+example.vuppeteer.yaml',
  ]

  @install_global_files = [ 
  # /. means all files (not sub-folders) non-recursive (shallow) 
  # /? means recursive, but only if matching an entry in the stack (a.yaml and a/*)
  # otherwise entries are recursive and non-conditional
    'bash/.',
    'bash/?',
    'facts/?',
    'hiera/?',
    'manifests/?',
    'templates/?',
    'templates/gitignore.example.erb',
    'templates/hiera.erb',
  ]

  @prov_uid = 0
  
  # #   @state_path = '/opt/puppetlabs/puppet/cache/state'

  def self.prep()
    temp_writable = FileManager.may?(:write, self.temp_path())
    Vuppeteer::shutdown('Error: temp_path is not configured as a writable path', -2) if !temp_writable
    FileUtils.rm_r(self.mirror_path, {:force => true})
    FileManager::path_ensure(self.mirror_path, FileManager::allow_dir_creation?)
    FileManager::path_ensure(self.import_target, FileManager::allow_dir_creation?)
    self.import_files().each do |i|
      if (i.include?(' AS '))
          i_parts = i.split(' AS ')
          import_source = i_parts[0]
          import_as = i_parts[1]
      else
          import_source = i
          import_as = File.basename(i)
      end
      self.import(import_source, import_as)
    end
    self.mirror(@install_files)
    self.mirror(@install_global_files, 'global.')
    #TODO
    #self._external_ensure() ??
  end

  def self.mirror(file_list, prefix = '') #TODO handle /. and /? matches
    to_path = self.mirror_path
    self_reference = File.absolute_path(Mr::active_path()) == File.absolute_path(to_path)
    Vuppeteer::shutdown("Error: Attempting to mirror self", -3) if self_reference
    p = "#{to_path}/#{prefix}"
    full_stack = Vuppeteer::get_stack([:optional,:greedy])
    MrUtils::enforce_enumerable(file_list).each do |f| 
      non_recursive = f.end_with?('/.')
      conditional = f.end_with?('/?')
      no_replace = f.start_with?('+')
      g = non_recursive || conditional ? f[0..-2] : f
      t = no_replace ? g[1..-1] : g
      target = "#{p}#{t}"
      finaltarget = "#{Mr::active_path()}/#{t}"
      source = "#{Mr::path()}/#{t}" 
      if (File.exist?(source))
        target_parent =  File.dirname(target)
        dir_mode = File.directory?(source)
        FileManager::path_ensure(target_parent, FileManager::allow_dir_creation?, false) if f.include?('/')
        #Vuppeteer::trace(dir_mode, source, "#{target_parent}", target)
        if ( dir_mode && (non_recursive || conditional))
          #Vuppeteer::say("cleanup #{target}", :prep)
          FileManager::path_ensure(target, FileManager::allow_dir_creation?, false)
          Dir.foreach(source) do |c| #TODO each_child not supported yet
            if (!['.','..'].include?(c))
              condition = c.split('.').first()
              #Vuppeteer::say("inspecting #{source}#{c}", :prep)
              if (File.file?("#{source}#{c}") && non_recursive)
                #Vuppeteer::say("shallow file #{source}#{c} #{target}#{c}", :prep)
                FileUtils.cp("#{source}#{c}", "#{target}#{c}")
                #Vuppeteer::shutdown("copy to #{target}#{c} failed") if !File.exist?("#{target}#{c}")
              elsif (conditional && full_stack.include?(condition))
                c_dir_mode = File.directory?("#{source}#{c}")
                #Vuppeteer::say("conditional #{condition} #{source}#{c} #{target}#{c}", :prep) if !c_dir_mode
                #Vuppeteer::say("conditional dir #{condition} #{source}#{c} #{target}", :prep) if c_dir_mode
                FileUtils.cp_r("#{source}#{c}", (c_dir_mode ? ("#{target}") : ("#{target}#{c}")), {:remove_destination => true})
              end
            end
          end
        elsif (no_replace && File.exist?(finaltarget))
          Vuppeteer::say("Notice: skipping install file #{prefix}#{f}, it already exists", :prep) if Vuppeteer::enabled?(:verbose)
          #TODO maybe copy but with an extra prefix e.g. example.
          #FileUtils.cp_r(source, (dir_mode ? ("#{target_parent}") : (target)), {:remove_destination => true})
        else
          #Vuppeteer::say("reset copy #{source} #{target} #{finaltarget}", :prep)
          FileUtils.cp_r(source, (dir_mode ? ("#{target_parent}") : (target)), {:remove_destination => true})
        end
      else
        Vuppeteer::say("Notice: unable to mirror install file #{prefix}#{f}", :prep)
      end
    end
  end

  def self.mirror_bash(source_path, target_path, file_list)
    FileManager::bash('file_mirror', self._mirror_view(source_path, target_path, file_list))
  end

  def self.mirror_provisioner(source_path, target_path, file_list, name = nil, always = true)
    name = "files+#{@prov_uid}" if name.nil?
    vm = VagrantManager::config().vm
    vm.provision name, type: :shell, run: (always ? 'always' : 'never') do |s|
      s.inline = self.mirror_bash(source_path, target_path, file_list)
    end
    # file_list.each do |c|
    #   FileUtils.rm("#{temp_state_path}/#{c}") if (File.exist?("#{temp_state_path}/#{c}"))
    #   FileUtils.cp("#{@state_path}/#{c}", "#{temp_state_path}/#{c}")
    # end
  end

  def self.import_files()
    Facts::get('import', [])
  end

  def self.temp_path()
    "#{Mr::active_path()}/#{FileManager::path(:temp)}"
  end

  def self.mirror_path()
    "#{self.temp_path}/ext/"
  end

  def self.import_target()
    "#{Mr::active_path()}/import"
  end

  def self.import(file_list, to_path)
    import_path = "#{self.temp_path}/imp"
    MrUtils::enforce_enumerable(file_list).each do |f|
      source = File.absolute_path(f)
      dir_mode = File.directory?(source)
      FileManager::path_ensure("#{import_path}/#{to_path}", FileManager::allow_dir_creation?, false)
      if (dir_mode)
        Dir.foreach(source) do |s| #TODO each_child not supported yet
          #TODO need to ignore .git, .gitignore, local-dev.* files...
          if (!['.','..'].include?(s))
            FileUtils.cp_r("#{source}/#{s}", "#{import_path}/#{to_path}", {:remove_destination => true})
          end
        end
      else 
        if (File.exist?(source))
          #TODO need to ignore .git, .gitignore, local-dev.* files...
          FileUtils.cp_r(source, "#{import_path}/#{to_path}", {:remove_destination => true})
        else
          Vuppeteer::say("Notice: #{source} unavailable for import", :prep) #TODO detect if it has been imported and indicate that
        end 
      end
      #FileUtils.cp_r(source, (dir_mode ? ("#{to_parent}") : (to_path)), {:remove_destination => true})
    end
  end

  def self.patch(what, data)
    case what
    when :install_global_files
      data = MrUtils::enforce_enumerable(data)
      @install_global_files += data
    else
      Vuppeteer::say("Warning: invalid installer patch #{what.to_s} specified", 'prep')
    end
  end

#################################################################
private
#################################################################

  ##
  # copies files from the external provisioner, but makes them project files (not "global.*")
  # def self.external_ensure() #TODO rename these to import files? clean up external/global distinction
  #   #TODO also support the same + mode as install_files? right now it looks like it is default behavior
  #   active = Mr::active_path()
  #   global = Vuppeteer::external? ? Mr::path() : "#{active}/global."
  #   list = MrUtils::enforce_enumerable(Vuppeteer::get_fact('global_files', []))
  #   list.each do |f|
  #     base_path = "#{active}/" + File.dirname(f)
  #     FileManager::path_ensure(base_path, FileManager::allow_dir_creation?)
  #     missing_text = "Error: Missing external file #{f}, not available externally"
  #     if (!File.exist?("#{active}/#{f}"))
  #       global_f = Vuppeteer::external? ? "#{global}/#{f}" : "#{global}#{f}"
  #       if File.exist?(global_f)
  #         Vuppeteer::say("Migrating external file #{f}", :prep)
  #         FileUtils.cp(global_f, "#{active}/#{f}")  if File.exist?(global_f)
  #       else 
  #         Vuppeteer::say(missing_text, :prep)
  #         #TODO setup a trigger to stop install in this case
  #         #Vuppeteer::shutdown(missing_text) if !File.exist?(global_f)
  #       end
  #     end
  #   end
  # end

  def self._mirror_view(s, t, f)
    Mirror.new(s, t, f).view()
  end

  class Mirror 
    @source_path = ''
    @target_path = ''
    @files = ''
    def initialize(s, t, f)
        @source_path = s
        @target_path = t
        @files = f
    end

    def view()
      return binding()
    end
  end


end