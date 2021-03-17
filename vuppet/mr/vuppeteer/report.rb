## 
# Encapsulates report management for mr
#

module Report
  extend self

  ##
  # collection of report data collected during build
  @report_matrix = {}
  
  ##
  # sensitive values that mr will try to avoid outputting to the terminal
  @sensitive = []

  ##
  # a buffer for post-run output
  @post_notices = ''

  def self.say(output, trigger = :now, formatting = true)
    trigger = :now if Vuppeteer::enabled?(:debug)
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
      full_output = VuppeteerUtils::filter_sensitive("#{line_tab}#{output}#{end_line}", @sensitive)
      trigger = [trigger] if !trigger.is_a? Array
      trigger.each do |t|
        t.to_sym
        t == :now ? (print full_output) : VagrantManager::store_say(full_output, t)
      end
    end
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
      self.say(MrUtils::trace(), :now, 2)
    end
    exit e.is_a?(Integer) ? e.abs : e
  end

  def self.push(facet, field, prop)
    @report_matrix[facet] = {} if !@report_matrix[facet]
    @report_matrix[facet][field] = [] if !@report_matrix[facet][field]
    @report_matrix[facet][field].push(prop)
  end

  def self.pop(facet, format = [:header, :extra_line])
    format = MrUtils::enforce_enumerable(format)
    head = format.include?(:header) ? "Report for \"#{facet}\": " : ''
    body = @report_matrix.has_key?(facet) ? @report_matrix[facet].to_s : '[] (none)'
    footer = format.include?(:extra_line) ? "\n" : ''
    return "#{head}#{body}#{footer}"
    @report_matrix.delete(facet)
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

  def self.mark_sensitive(s)
    s = MrUtils::enforce_enumerable(s)
    s.each() do |v|
      @sensitive.push(v)
    end
  end

  def self.filter_sensitive(s)
    return VuppeteerUtils::filter_sensitive(s, @sensitive)
  end

  def self.get_sensitive()
    @sensitive
  end

#################################################################
  private
#################################################################



end