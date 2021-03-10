## 
# Base Interface MrRogers provides to provisioners
#

module MrUtils
  extend self

  require 'pp'

  def self.sym_keys(h) #NOTE workaround until Ruby 2.5? h = h.transform_keys(&:to_s)
    h.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  end

  def self.enforce_enumerable(a)
    return a.class.include?(Enumerable) ? a : [a]
  end

  def self.inspect(v)
    v.pretty_inspect
  end

  def self.trace(local = true)
    trace_stack = caller[1..-1]
    trace_end = local ? (1 + trace_stack.find_index {|t| t.start_with?(Mr::path() + '/mr.rb')}) : -1
    return trace_stack[0..trace_end]
  end

  def self.caller_file(entries)
    min = entries[0].index('/')
    max = entries[0].index(':', min)
    entries[0].slice(0, max)
  end

  def self.meditate(message, critical = false, trigger = 'prep')
    fatal = critical && critical.class == TrueClass
    label = fatal ? 'Error' : (critical.class == String ? critical : 'Notice')
    Vuppeteer::shutdown("#{label}: #{message}", -5) if fatal
    Vuppeteer::say("#{label}: #{message}", trigger)
  end

  def self.search(matches, search, throws = false)
    matches = [matches] if !matches.is_a?(Array)
    while matches.length > 0
      m = matches.shift
      #print([__FILE__,__LINE__,matches,search,m].to_s)
      t = self.traversable(m) ? self.traverse(m, search, throws) : nil 
      return t if !t.nil?
      h = search.is_a?(Hash) && search.has_key?(m)
      a = search.is_a?(Array) && m.is_a?(Integer) && m < search.length
      return search[m] if h || a
    end
    raise 'failed search' if throws
    return nil
  end

  def self.traverse(index, search, throws = false)
    indexes = self.traversable(index) ? index.split('::') : self.enforce_enumerable(index)
    n = indexes.shift
    n = n.to_i if n.match(/^[0-9]*$/)
    indexes = indexes.join('::')
    h = search.is_a?(Hash) && search.has_key?(n)
    a = search.is_a?(Array) && n.is_a?(Integer) && n < search.length
    if h || a
      return indexes.length == 0 ? search[n] : self.traverse(indexes, search[n], throws) 
    end
    raise 'failed traverse' if throws
    return nil
  end

  def self.traversable(index)
    return index.class == String && index.include?('::')
  end
  
  def self.dig(h, k)
    h && h.class == Hash && h.has_key?(k) ? h[k] : nil
  end

  def self.clean_whitespace(a)
    return if a.class == String
    if a.class.include?(Enumerable)
      n = []
      a.each do |l|
        n.push(l&.to_s.strip())
      end
      return n
    end
    ''
  end

end