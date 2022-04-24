## 
# Util functions for Mr
#

module MrUtils
  extend self


  require 'pp'

  @splitter = '::'

  def self.splitter()
    @splitter
  end

  def self.sym_keys(h) #NOTE workaround until Ruby 2.5? h = h.transform_keys(&:to_s)
    h.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  end

  def self.string_keys(h)
    h.inject({}){|memo,(k,v)| memo[k.to_s] = v; memo}
  end

  def self.enforce_enumerable(a, even_nil = true)
    return a.class.include?(Enumerable) ? a : (!even_nil && a.nil? ? a : [a])
  end

  def self.inspect(v, breakup = false)
    breakup ? v.pretty_inspect.split("\n") : v.pretty_inspect
  end

  def self.trace(local = true)
    trace_stack = caller[1..-1]
    internal = trace_stack.find_index {|t| t.start_with?(Mr::path() + '/mr.rb')}
    internal = trace_stack.find_index {|t| t.start_with?(Mr::path() + '/mr/')} if !internal
    trace_end = local && internal ? (1 + internal) : -1
    return trace_stack[0..trace_end]
  end

  def self.caller_file(entries, options = nil)
    min = entries[0].index('/')
    max = entries[0].index(':', min)
    file = entries[0].slice(0, max)
    case options
    when :line
      next_max = entries[0].index(':', max + 1) - 1
      file += " #{entries[0].slice(max + 1, next_max - max)}"
    end
    file
  end

  def self.search(matches, search, throws = false)
    remaining = self.enforce_enumerable(matches).clone()
    while remaining.length > 0
      m = remaining.shift
      #Vuppeteer::trace(remaining,search,m)
      t = self.traversable?(m) ? self.traverse(m, search, throws) : nil 
      return t if !t.nil?
      h = search.is_a?(Hash) && search.has_key?(m)
      a = search.is_a?(Array) && m.is_a?(Integer) && m < search.length
      return search[m] if h || a
    end
    raise 'failed search' if throws
    return nil
  end

  def self.traverse(index, search, throws = false)
    return search if index == @splitter
    indexes = self.traversable?(index) ? index.split(@splitter) : self.enforce_enumerable(index)
    n = indexes.shift
    n = n.to_i if n.match(/^[0-9]*$/)
    indexes = indexes.join(@splitter)
    h = search.is_a?(Hash) && search.has_key?(n)
    a = search.is_a?(Array) && n.is_a?(Integer) && n < search.length
    if h || a
      return indexes.length == 0 ? search[n] : self.traverse(indexes, search[n], throws) 
    end
    raise 'failed traverse' if throws
    return nil
  end

  def self.traversable?(index)
    return index.is_a?(String) && index.include?(@splitter)
  end
  
  def self.dig(h, k)
    h && h.is_a?(Hash) && h.has_key?(k) ? h[k] : nil
  end

  def self.clean_whitespace(a)
    return if a.is_a?(String)
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