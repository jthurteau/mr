## 
# Utils for Vuppeteer
#

module VuppeteerUtils
  extend self

  require 'erb'

  Tabs = '    '.freeze

  @char_sets = {
    'lal' => 'abcdefghijklmnopqrstuvwxyz',
    'ual' => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    'bin' => '01',
    'oct' => '234567',
    'dec' => '89',
    'math' => '+=*/%',
    'punc' => '.-_!?',
    'symb' => '#@$&',
    'brac' => '[]{}<>'
  }

  @requirement_types = [
    :boolean,
    :true,
    :false,
    :integer,
    :positive_integer,
    :negative_integer,
    :non_positive_integer,
    :non_negative_integer,
    :hash,
    :array,
    :enumerable,
    :in,
    :not_in,
    :include,
    :include_any,
    :not_include,
    :not_include_any,
    :string,
    :string_length,
    :string_complexity,
    :string_regex,
    :members,
  ]

  @generation_options = [
    :derived,
    :random,
  ]

  @storable = [:random]
  @default_match_method = :not_nil
  @default_calc_method = :random

  
  def self.rand(conf = {})
    length = conf&.dig('length')
    length = 16 if length.nil? || length < 1
    set = conf&.has_key?('set') ? conf['set'] : :alnum
    if (set.is_a?(Symbol))
      set_string = set.to_s
      set = ''
      sets = @char_sets.clone
      sets.each do |s,c|
        if set_string.include?(s)
        set += c
        sets.delete(s)
        end
      end
      if set_string.include?('al') && !set_string.include?('lal') && !set_string.include?('ual')
        set += sets['lal'] if sets['lal']
        set += sets['ual'] if sets['ual']
      end
      if set_string.include?('num')
        set += sets['bin'] if sets['bin']
        set += sets['oct'] if sets['oct']
        set += sets['dec'] if sets['dec']
      end
    end
    set = @char_sets.join() if (set == '')
    value = self.random_string(set, length)
    Vuppeteer::mark_sensitive(value) if conf&.dig('sensitive') && conf['sensitive']
    value
  end

  
  def self.random_string(char_set = ['0123456789abcedf'], length = 16)
    s = Random.new_seed()
    r = ''
    length.to_i.times do |n|
      rn = Random.rand(char_set.length)
      r += char_set[rn]
    end
    r
  end

  def self.sensitive_fact?(k)
    return true if self.sensitive_facts().any?() { |s| s.start_with?('*') && k.end_with?(s[1..-1]) }
    false
  end

  def self.sensitive_facts()
    ['*_pat','*_pass', '*_password', '*_key', '*_secret']
  end

  def self.meditate(message, critical = false, trigger = :prep)
    fatal = critical && critical.is_a?(TrueClass)
    label = fatal ? 'Error' : (critical.is_a?(String) ? critical : 'Notice')
    Vuppeteer::shutdown("#{label}: #{message}", -5) if fatal
    Vuppeteer::say("#{label}: #{message}", trigger)
  end

  # def self.valid?(v, criteria = nil)
  #   return false
  # end

  def self.storable?(method)
    #Vuppeteer::trace(method)
    method[:method] = @default_calc_method if method.is_a?(Hash) && !method.include?(:method) 
    lookup_method = method.is_a?(Hash) ? method[:method] : method
    lookup_method.is_a?(Symbol) && @storable.include?(lookup_method)
  end

  def self.matchable?(method)
    return method.is_a?(Hash) && method.any?() {|k| k.is_a?(String)}
  end

  def self.verify(list, check, checked = []) #TODO use checked to detect conflicts
    #Vuppeteer::trace(list, list.class, check, checked)
    errors = []
    list.each do |r|
      if (r.is_a?(Hash))
        r.each do |k, v|
          if (self.matchable?(v))
            result = check.has_key?(k) && self.matches?(v, check[k])
          else
            result = check.has_key?(k) && v == check[k] #Facts::get(k) != v
            # raise "Error: duplicate conflicting assert for #{k}." if
          end
          description = !check.has_key?(k) ? 'missing asserted ' : '';
          errors.push("Error: #{description}fact \"#{k}\" does not match expected value \"#{v}\" during boxing") if !result
          checked.push(k)
        end
      elsif (r.is_a?(Array))
        current = r.shift()
        stack = checked + [current]
        if (check.has_key?(current) && r.length() > 1)
          errors += self.verify(r, check[current], stack)
        elsif (r.length() > 0 && [Hash, Symbol].include?(r[0].class))
          match = r[0].is_a?(Symbol) ? {method: r[0]} : r[0] #TODO we don't currently accept symbol matches on root, otherwise we might generalise this recursion a different way
          errors += self.verify({current => match}, check, stack)
        elsif(!check.has_key?(current))
          joined = (stack + r).join(':')
          errors.push("Error: missing asserted fact: \"#{joined}\" during boxing")
        end
        checked.push(stack.join(':'))        
      elsif ([String].include? r.class)
        errors.push("Error: missing asserted fact: \"#{r}\" during boxing") if !check.has_key?(r)
        checked.push(r)
      else
        r_string = r.to_s
        r_class = r.class.to_s
        errors.push("Error: misconfigured requirement: (#{r_class})#{r_string}")
      end
    end
    errors
  end

  def self.matches?(config, value)
    case(config.is_a?(Hash) && config.has_key?(:match) ? config[:match] : @default_match_method)
    when :calculate
      self.calculate(config) == value
    else
      false
    end
  end

  def self.calculate(config, k = nil)
    #Vuppeteer::trace('calculate', config, k)
    return Vuppeteer::get_fact(config) if config.is_a?(String)
    if (config.is_a?(Array)) 
      config.each() do |v|
        return Vuppeteer::get_fact(v) if v.is_a?(String) && Vuppeteer::fact?(v)
      end
    end
    config[:method] = @default_calc_method if config.is_a?(Hash) && !config.has_key?(:method)
    self._calculate(config.is_a?(Symbol) ? {method: config} : config, k)
  end

  def self.generate(list)
    #Vuppeteer::trace('generating', list)
    result = {}
    list.each() do |k, m|
       result[k] = self.calculate(m, k)
    end
    result
  end

  def self.filter_sensitive(s, f)
    return self.filter_sentitive_string(s, f) if s.is_a?(String)
    r = s.class.new
    if (s.is_a?(Hash))
      s.each() do |k,v| 
        v = self.stringify(v)
        if(v.is_a?(String))
          r[k] = self.filter_sentitive_string(v, f)
        else
          r[k] = v.class.include?(Enumerable) ? self.filter_sensitive(v, f) : v
        end
      end
    elsif (s.is_a?(Array))
      s.each() do |v| 
        v = self.stringify(v)
        if(v.is_a?(String))
          r.push(self.filter_sentitive_string(v, f))
        else
          r.push(v.class.include?(Enumerable) ? self.filter_sensitive(v, f) : v)
        end
      end
    end
    r
  end

  def self.filter_sentitive_string(s, f)
    r = s.clone
    f.each do |m|
      r = (r ? r.gsub(m, '__REDACTED_AS_SENSITIVE__') : '')
    end
    r
  end

  def self.stringify(v)
    return [Symbol, Integer, Float, TrueClass, FalseClass, NilClass].include?(v.class) ? (v.to_s) : v
  end

  
  def self.script(script_name, view = nil)
    type = view ? 'erb' : 'sh'
    #TODO filter out funny path navigations in script_name
    #TODO error when if statement is the first line? error when first line is blank?
    file_name = "#{script_name}.#{type}"
    path = FileManager::path(:bash, file_name)
    source = FileManager::path_type(path)
    Vuppeteer::report('bash', source, script_name)
    raise "Unable to load script #{file_name}  #{path}/#{file_name}" if !File.readable?("#{path}/#{file_name}")
    #Vuppeteer::shutdown("failed to load script #{script_name}", -5)
    contents = File.read("#{path}/#{file_name}")
    # if(contents.include?("\r"))
    #   Vuppeteer::trace('no',contents.include?("\r"),contents.include?("\r\n"));
    #   exit
    # end
    return contents if(!view)
    #TODO catch and handle parse errors
    return ERB.new(contents, nil, '-').result(view);
  end

  #################################################################
  private
  #################################################################

  def self._calculate(config, seed = nil)
    #Vuppeteer::trace('actually calculate', config, seed)
    case config[:method]
    when :derived
      self.calculate(config[:source])
    when :random
      self.rand(config)
    else
      nil
    end
  end

end