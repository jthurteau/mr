## 
# Manages Host operations for Vuppeteer
#

module Host
  extend self

  ##
  # values from the instance_facts at session start
  @instance = nil

  ##
  # indicates something changed the instance during this session
  @instance_changed = false

  # @timezone = 'America/New_York' #TODO

  def self.init(instance_facts)
    @instance = instance_facts
  end

  #TODO support a trigger param?
  def self.command(c)
    current_dir = Dir.pwd()
    if (c.is_a?(Hash)) 
      Dir.chdir(c.dig(:path)) if c.has_key?(:path)
      #NOTE default behavior is stderr > stdin to avoid leaking output prematurely
      say_errors = !c.has_key?(:redirect_errors) || !c[:redirect_errors] 
      command = c.dig(:cmd)
      say_when = c.dig(:when) ? c.dig(:when) : :now
      say_echo = c.dig(:echo) ? c.dig(:echo) : false
      Vuppeteer::say(c.dig(:say), say_when) if c.has_key?(:say)
      self.tunnel(command + (say_errors ? ' 2>&1' : ''), say_echo, say_when) if command
    else
      self.tunnel("#{c} 2>&1")
    end
    Dir.chdir(current_dir) if (!c.is_a?(Hash) || !c.has_key?(:hold_path) || !c[:hold_path])
  end

  ##
  # updates the instance facts
  # if passed a key and value, it will "lazy_save" which may result in loss of data
  # if the current process fails
  # pass a hash and true to force immediate state changes
  def self.update(k, v = nil?)
    #Vuppeteer::trace('updating instance', k, v)
    @instance = {} if @instance.nil? && (k.class == Hash || !v.nil?)
    if (k.class == Hash) 
      k.each() do |hk, hv|
        self.update(hk, hv)
      end
      self.save(true) if v
      return
    end
    if (!v.nil? && (!@instance.has_key?(k) || v != @instance[k]))
      #Vuppeteer::trace('updating add', k, v)
      @instance[k] = v
      Facts::promote(k, v)
      @instance_changed = true
    elsif (!@instance.nil? && @instance.has_key?(k) && v.nil?)
      #Vuppeteer::trace('updating removing', k)
      Facts::demote(k)
      @instance_changed = true
      @instance.delete(k)
    end
  end

  def self.save(verbose = false)
    #Vuppeteer::trace('saving instance', @instance)
    return if Vuppeteer::feature(:instance).class != String || !@instance_changed
    saved = FileManager::save_yaml(Vuppeteer::feature(:instance), @instance)
    @instance_changed = false if @instance_changed && saved
    Vuppeteer::say('Notice: Updated the instance facts file') if saved && verbose
  end

  def self.instance(key = nil)
    return key.nil? ? Vuppeteer::enabled?(:instance) : (@instance && @instance.has_key?(key) ? @instance[key] : nil)
  end

  #TODO see how this is used and if it should also be queued for input on trigger
  def self.tunnel(input, echo = false, output_trigger = :now)
    i = input.end_with?("\n") ? input : "#{input}\n"
    o = `#{i}`
    Vuppeteer::say(input, output_trigger) if echo
    Vuppeteer::say(o, output_trigger) if !o.empty?
  end

#################################################################
  private
#################################################################


end