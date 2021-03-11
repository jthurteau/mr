## 
# Base Interface MrRogers provides to provisioners
#

module Vuppeteer
    extend self

    require_relative 'vuppeteer/utils'
    require_relative 'vuppeteer/facts'
    require_relative 'vuppeteer/host'
    require_relative 'vuppeteer/installer'
    require_relative 'vuppeteer/report'
  
    ##
    # indicates ::init has alread been called
    @initialized = false

    ##
    # enables additional output about what's going on step-by-step
    @verbose = false

    ##
    # indicates the path to external mr, if any
    @external_path = nil

    ##
    # a buffer for post-run output
    @post_notices = ''

    ##
    # sensitive values that mr will try to avoid outputting to the terminal
    @sensitive = []

    ##
    # values from the instance_facts at session start
    @instance = nil

  # #   @timezone = 'America/New_York' #TODO   
  # #   @when_to_reregister = ['never', 'always'][0]

    ##
    # indicates something changed the instance during this session
    @instance_changed = false
 
    @features = {
      verbose: false,
      local: true,
      global: true,
      developer: false,
      stack: true,
      instance: true,
      installer: false,
    }

    def self.init(path = nil)
      return if @initialized
      @external_path = path
      @initialized = true
      if (self.external?)
        self.say("External Mr #{external_path} managing build.", 'prep')
        @features[:installer] = true
      end
      Facts::init()
      @features[:instance] = "#{Mr::active_path}/#{FileManager::localize_token}.instance.yaml"
      @instance = Facts::instance()
      @features[:verbose] = Facts::get('verbose')
    end

    def self.disable(o)
      @features[o] = false
    end
    
    def self.enable(o)
      @features[o] = true
    end

    def self.enabled?(o)
      @features.has_key?(o) && @features[o]
    end

    def self.external?
      return !@external_path.nil?
    end
  
    def self.external_path
      return @external_path
    end

    def self.start()
      self.expose_facts() if Facts::get('verbose_facts') || @features[:verbose]
      if (self.external?)
        Vuppeteer::shutdown('attempting install::prep')
        Installer::prep() if @features[:installer]
      end
    end

    def self.bow
      self.save_instance() if @instance_changed
    end

    def self.say(output, trigger = :now, formatting = true)
      if (output.class.include?(Enumerable))
        output.each do |o|
          self.say(o, trigger, formatting)
        end
      else
        supress_endline = formatting && (formatting.class == FalseClass || formatting == :no_end)
        suppress_linetab = formatting && (formatting.class == FalseClass || formatting == :no_indent)
        tab_multi = formatting && formatting.class == Integer ? formatting : 1
        end_line = supress_endline ? '' : "\n\r"
        line_tab = suppress_linetab ? '' : (VuppeteerUtils::Tabs * tab_multi)
        full_output = "#{line_tab}#{output}#{end_line}"
        trigger = [trigger] if !trigger.is_a? Array
        trigger.each do |t|
          t.to_sym
          t == :now ? (print full_output) : VagrantManager::store_say(full_output, t)
        end
      end
    end
  
    def self.remember(output)
      if (output.class.include?(Enumerable)) 
        output.each() do |o|
          self.remember(o)
        end
        return
      end
      @post_notices += "echo #{output}\n"
    end
  
    def self.pull_notices()
      notices = @post_notices
      @post_notices = ''
      return notices
    end

    def self.perform_host_commands(commands)
      return if commands.nil?
      current_dir = Dir.pwd()
      commands.each do |c|
        Host::command(c)
      end
      Dir.chdir(current_dir)
    end
  
    ##
    # exits with an error message an optional status code
    # status code e defaults to 1
    # if e is negative, a stack trace is printed before exiting with the absolute value of e
    def self.shutdown(s, e = 1)
      s[s.length() - 1] += ', shutting Down.' if s.class == Array
      self.say(s.class == Array ? s : (s + ', shutting Down.'))
      if e < 0
        self.say('Mr Shutdown Trace:')
        self.say(MrUtils.trace(), :now, 2)
      end
      exit e.is_a?(Integer) ? e.abs : e
    end

    def self.instance(key = nil)
      return key.nil? ? @features[:instance] : (@instance && @instance.has_key?(key) ? @instance[key] : nil)
    end

    def self.update_instance(k, v = nil?)
      @instance = {} if @instance.nil? && (k.class == Hash || !v.nil?)
      if (k.class == Hash) 
        k.each() do |hk, hv|
          self.update_instance(hk, hv)
        end
        self.save_instance() if v
        return
      end
      self.set_facts({k => v}, true)
      if (!v.nil? && (!@instance.has_key?(k) || v != @instance[k]))
        @instance[k] = v
        @instance_changed = true
      elsif (!@instance.nil? && @instance.has_key?(k))
        @instance_changed = true
        @instance.delete(k)
      end
    end
  
    def self.save_instance()
      return if !@features[:instance] || @features[:instance].class != String
      FileManager::save_yaml(@features[:instance], @instance)
    end

    # def self.mark_sensitive(s)
    #   @sensitive.push(s)
    # end
  
    # def self.get_sensitive()
    #   return @sensitive
    # end
  
    def self.filter_sensitive(s)
      return VuppeteerUtils::filter_sensitive(s)
    end
  
    def self.report(facet, field = nil, prop = nil)
      Report::push(facet, field, prop) if !field.nil? && !prop.nil?
    end
  
    def self.expose_facts()
      self.say(
        [
          'Processed Facts:',
          MrUtils::inspect(Facts::facts()), 
          '----------------',
        ], 'prep'
      )
    end

    def self.import_files()
      return Facts::get('import', [])
    end

    def self.sync()
      RepoManager::init() if (Facts::fact?('project_repos'))
    end

    def self.trace(*s)
      c = MrUtils::caller_file(caller, :line)
      self.say("TRACE #{c} #{s.to_s}") if @features[:verbose]
    end

  #################################################################
  # delegations
  #################################################################

    def self.get_fact(f, default = nil)
      Facts::get(f, default)
    end
  
    def self.set_facts(f, m = false)
      Facts::set(f, m)
    end

    def self.facts(list = nil)
      Facts::facts()
    end

    def self.fact?(f)
      Facts::fact?(f)
    end

    def self.load_facts(source)
      source.start_with?('::') ? Facts::get(source[2..-1]) : FileManager::load_fact_yaml(source, false)
    end

    def self.add_derived(d)
      if () 
        self.say("Warning: invalid derived facts sent during Puppet initialization",'prep')
        return
      end
      Facts::register_generated(d)
    end

  #################################################################
  # gateways
  #################################################################

    def self.post_stack()
      Facts::post_stack()
    end

    def self.set_root_facts(f)
      Facts::roots(f)
    end

    def self.add_asserts(v)
      Facts::asserts(v)
    end
  
    def self.add_requirements(v)
      Facts::requirements(v)
    end

    def self.register_generated(v)
      Facts::register_generated(v)
    end

    def self.install_files()
      return Installer::install_files() if @features[:installer]
    end
  
    def self.global_install_files()
      return Installer::global_install_files() if @features[:installer]
    end

  #################################################################
  private
  #################################################################
  
  
  end