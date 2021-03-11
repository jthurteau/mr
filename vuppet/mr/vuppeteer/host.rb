## 
# Manages Host operations for Vuppeteer
#

module Host
  extend self

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