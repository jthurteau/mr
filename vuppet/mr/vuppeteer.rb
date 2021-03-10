## 
# Base Interface MrRogers provides to provisioners
#

module Vuppeteer
    extend self

    require_relative 'vuppeteer/utils'
    require_relative 'vuppeteer/facts'
    require_relative 'vuppeteer/installer'
    require_relative 'vuppeteer/report'
  
    Tabs = '    '.freeze
  
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
 
    def self.init(path = nil)
      return if @initialized
      @external_path = path
      @initialized = true
      if (self.external?)
        self.say("External Mr #{external_path} managing build.", 'prep')
        Installer::enable()
      end
      Facts::init()
    end
  
    def self.external?
      return !@external_path.nil?
    end
  
    def self.external_path
      return @external_path
    end

    def self.start()
      self.expose_facts() if Facts::get('verbose_facts') || Facts::get('verbose')
      if (self.external?)
        Installer::prep()
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
        line_tab = suppress_linetab ? '' : (Vuppeteer::Tabs * tab_multi)
        full_output = "#{line_tab}#{output}#{end_line}"
        trigger = [trigger] if !trigger.is_a? Array
        trigger.each do |t|
          t.to_sym
          t == :now ? (print full_output) : VagrantManager::store_say(full_output, t)
        end
      end
    end
  
    #TODO see how this is used and if it should also be queued for input on trigger
    # def self.tunnel(input, echo = false, output_trigger = :now)
    #   i = input.end_with?("\n") ? input : "#{input}\n"
    #   o = `#{i}`
    #   self.say(input, output_trigger) if echo
    #   self.say(o, output_trigger) if !o.empty?
    # end
  
    def self.remember(output)
      @post_notices += "echo #{output}\n"
    end
  
    def self.pull_notices()
      notices = @post_notices
      @post_notices = ''
      return notices
    end

    # def self.perform_host_commands(commands)
    #   current_dir = Dir.pwd()
    #   commands.each do |c|
    #     if (c.is_a?(Hash)) 
    #       Dir.chdir(c.dig(:path)) if c.has_key?(:path)
    #       #NOTE default behavior is stderr > stdin to avoid leaking output prematurely
    #       say_errors = !c.has_key?(:redirect_errors) || !c[:redirect_errors] 
    #       command = c.dig(:cmd)
    #       say_when = c.dig(:when) ? c.dig(:when) : :now
    #       say_echo = c.dig(:echo) ? c.dig(:echo) : false
    #       self.say(c.dig(:say), say_when) if c.has_key?(:say)
    #       self.tunnel(command + (say_errors ? ' 2>&1' : ''), say_echo, say_when) if command
    #     else
    #       self.tunnel("#{c} 2>&1")
    #     end
    #     Dir.chdir(current_dir) if (!c.is_a?(Hash) || !c.has_key?(:hold_path) || !c[:hold_path])
    #   end
    #   Dir.chdir(current_dir)
    # end
  
    # def self.translate_guest_commands(commands)
    #   command_string = ''
    #   commands.each do |c|
    #     if (c.is_a?(Hash)) 
    #       command_string += "cd #{commandc.dig(:path)}" if c.has_key?(:path)
    #       command = c.dig(:cmd)
    #       command_string += "#{command}\n" if command
    #       #TODO support :say directive
    #       #TODO support returning to original :path
    #     else
    #       command_string += "#{c}\n"
    #     end
    #   end
    #   command_string
    # end
  
    ##
    # exits with an error message an optional status code
    # status code e defaults to 1
    # if e is negative, a stack trace is printed before exiting with the absolute value of e
    def self.shutdown(s, e = 1)
      self.say(s + ', shutting Down.')
      if e < 0
        self.say('Mr Shutdown Trace:')
        self.say(MrUtils.trace(), :now, 2)
      end
      exit e.is_a?(Integer) ? e.abs : e
    end

    # def self.mark_sensitive(s)
    #   @sensitive.push(s)
    # end
  
    # def self.get_sensitive()
    #   return @sensitive
    # end
  
    # def self.generate(method, hash)
    #   generated_hash = {}
    #   hash.each do |k,v|
    #     generated_hash[k] = self._generate(method, v)
    #   end
    #   generated_hash
    # end
  
    # def self.filter_sensitive(s)
    #   return self._filter_sentitive_string(s) if s.class = String
    #   r = s.class.new
    #   s.each do |k,v| 
    #     if(v.class == String)
    #       r[k] = self._filter_sentitive_string(v)
    #     else
    #       r[k] = v.class.include?(Enumerable) ? self.filter_sensitive(v) : v
    #     end
    #   end
    #   r
    # end
  
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
  

    # def self.update_instance(m, v)
    #   @instance = {} if @instance.nil? && !v.nil?
    #   if (!v.nil?)
    #     @instance[m] = v
    #     @instance_changed = true
    #   elsif (!@instance.nil?)
    #     @instance_changed = true
    #     @instance.delete(m)
    #   end
    # end
  
    # def self.save_instance()
    #   localize_token = FileManager::localize_token()
    #   FileManager::save_yaml("#{Mr::active_path()}/#{localize_token}.instance.yaml", @instance)
    # end

    def self.install_files()
      return Installer::install_files()
    end
  
    def self.global_install_files()
      return Installer::global_install_files()
    end

    def self.import_files()
      return Facts::get('import', [])
    end

    def self.verify()
      Facts::requirements().each do |r|
        if (r.class == Hash)
          r.each do |k, v|
            self.shutdown("Error: fact \"#{k}\" does not match expected value \"#{v}\" during boxing") if Facts::get(k) != v
          end
        elsif (r.class == Array)
          r.each do |k|
            self.shutdown("Error: Missing assert fact: \"#{k}\" during boxing") if !Facts::fact?(k)
          end
        else
          r_string = r.to_s
          self.shutdown("Error: Misconfigured requirement: #{r_string}")
        end
      end
      self.shutdown("Notice: Passed Verification", -1)
    end

    def self.sync()
      RepoManager::init() if (Facts::fact?('project_repos'))
    end

    def self.register_generated(v)
      Facts::register_generated(v)
    end
  
    def self.set_asserts(v)
      Facts::set_asserts(v)
    end
  
    def self.add_requirements(v)
      Facts::add_requirements(v)
    end
  
    def self.disable(o)
      Facts::disable(o)
    end
  
    def self.set_asserts(a)
      Facts::set_asserts(a)
    end
  
    def self.set_root_facts(f)
      Facts::set_root_facts(f)
    end
  
    def self.get_fact(f, d = nil)
      Facts::get(f, d)
    end
  
    def self.set_facts(f, m = false)
      Facts::set(f, m)
    end

    def self.facts()
      Facts::facts()
    end

    def self.fact?(f)
      Facts::fact?(f)
    end

    def self.set_derived(d)
      Facts::set_derived(d)
    end

    def self.post_stack()
      Facts::post_stack()
    end

  #################################################################
  private
  #################################################################
  
    # def self._filter_sentitive_string(s)
    #   r = s.clone
    #   @sensitive.each do |f|
    #     r = r.gsub(f, '__REDACTED_AS_SENSITIVE__')
    #   end
    #   r
    # end
  
    # def self._load_milestones()
    #   @milestones = FileManager::load_fact_yaml("#{Mr::active_path()}/#{@milstone_file}", false)
    #   @milstones_changed = false
    # end
  
    # def self._generate(method, config)
    #   case method
    #   when :random, 'random'
    #     VuppeteerUtils::rand(config)
    #   end
    # end
  
  end