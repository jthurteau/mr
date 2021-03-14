## 
# Encapsulates host file management for Mr
#

module FileMirror
  extend self

  @prov_uid = 0
  
  # #   @state_path = '/opt/puppetlabs/puppet/cache/state'

  def self.mirror(file_list, to_path, prefix = '') #TODO handle /. and /? matches
    self_reference = File.absolute_path(Mr::active_path()) == File.absolute_path(to_path)
    raise "attempting to mirror self" if self_reference
    p = "#{to_path}#{prefix}"
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
        self.path_ensure(target_parent, self.allow_dir_creation?, false) if f.include?('/')
        #Vuppeteer::trace(dir_mode, source, "#{target_parent}", target)
        if ( dir_mode && (non_recursive || conditional))
          #Vuppeteer::say("cleanup #{target}", 'prep')
          self.path_ensure(target, self.allow_dir_creation?, false)
          Dir.foreach(source) do |c| #TODO each_child not supported yet
            if (!['.','..'].include?(c))
              condition = c.split('.').first()
              #Vuppeteer::say("inspecting #{source}#{c}", 'prep')
              #if non-recursive, copy if not a directory
              if (File.file?("#{source}#{c}") && non_recursive)
                #Vuppeteer::say("shallow file #{source}#{c} #{target}#{c}", 'prep')
                FileUtils.cp("#{source}#{c}", "#{target}#{c}")
                #Vuppeteer::shutdown("copy to #{target}#{c} failed") if !File.exist?("#{target}#{c}")
              elsif (conditional && Vuppeteer::get_stack('+optional-extensions').include?(condition))
                c_dir_mode = File.directory?("#{source}#{c}")
                #Vuppeteer::say("conditional #{condition} #{source}#{c} #{target}#{c}", 'prep') if !c_dir_mode
                #Vuppeteer::say("conditional dir #{condition} #{source}#{c} #{target}", 'prep') if c_dir_mode
                FileUtils.cp_r("#{source}#{c}", (c_dir_mode ? ("#{target}") : ("#{target}#{c}")), {:remove_destination => true})
              end
            end
          end
        elsif (no_replace && File.exist?(finaltarget))
          Vuppeteer::say("Notice: skipping install file #{prefix}#{f}, it already exists",'prep')
          #TODO maybe copy but with an extra prefix e.g. example.
          #FileUtils.cp_r(source, (dir_mode ? ("#{target_parent}") : (target)), {:remove_destination => true})
        else
          #Vuppeteer::say("reset copy #{source} #{target} #{finaltarget}", 'prep')
          FileUtils.cp_r(source, (dir_mode ? ("#{target_parent}") : (target)), {:remove_destination => true})
        end
      else
        Vuppeteer::say("Notice: unable to mirror install file #{prefix}#{f}",'prep')
      end
    end
  end

  def self.mirror_bash(source_path, target_path, file_list)
    FileManager::bash('file_mirror', self::_mirror_view(source_path, target_path, file_list))
  end

  def self.mirror_provisioner(source_path, target_path, file_list, name = nil, always = true)
    name = "files+#{@prov_uid}" if name.nil?
    vm = VagrantManager::config().vm
    vm.provision name, type: :shell, run: (always ? 'always' : 'never') do |s|
      s.inline = self::mirror_bash(source_path, target_path, file_list)
    end
    # file_list.each do |c|
    #   FileUtils.rm("#{temp_state_path}/#{c}") if (File.exist?("#{temp_state_path}/#{c}"))
    #   FileUtils.cp("#{@state_path}/#{c}", "#{temp_state_path}/#{c}")
    # end
  end

  def self.import(file_list, to_path)
    MrUtils::enforce_enumerable(file_list).each do |f|
      source = File.absolute_path(f)
      dir_mode = File.directory?(source)
      self.path_ensure(to_path, self.allow_dir_creation?, false)
      if (dir_mode)
        Dir.foreach(source) do |s| #TODO each_child not supported yet
          #TODO need to ignore .git, .gitignore, local-dev.* files...
          if (!['.','..'].include?(s))
            FileUtils.cp_r("#{source}/#{s}", to_path, {:remove_destination => true})
          end
        end
      else 
        if (File.exist?(source))
          #TODO need to ignore .git, .gitignore, local-dev.* files...
          FileUtils.cp_r(source, to_path, {:remove_destination => true})
        else
          Vuppeteer::say("Notice: #{source} unavailable for import", 'prep') #TODO detect if it has been imported and indicate that
        end 
      end
      #FileUtils.cp_r(source, (dir_mode ? ("#{to_parent}") : (to_path)), {:remove_destination => true})
    end
  end

#################################################################
  private
#################################################################

  def self._copy_unique_files(from, to, max_back = 2)
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