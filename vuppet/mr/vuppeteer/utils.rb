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

  def self.valid?(v, criteria = nil)
    return false
  end

  def self.storable?(method)
    #Vuppeteer::trace(method)
    return method.is_a?(Hash) || @storable.include?(method)
  end

  def self.verify(list, check, checked = [])
    #Vuppeteer::trace(list, list.class, check, checked)
    errors = []
    list.each do |r|
        if (r.is_a?(Hash))
          r.each do |k, v|
            result = check.has_key?(k) && v == check[k] #Facts::get(k) != v
            # raise "Error: duplicate conflicting assert for #{k}." if
            errors.push("Error: missing asserted fact \"#{k}\" does not match expected value \"#{v}\" during boxing") if !result && !check.has_key?(k)
            errors.push("Error: fact \"#{k}\" does not match expected value \"#{v}\" during boxing") if !result && check.has_key?(k)
            checked.push(k)
          end
        elsif (r.is_a?(Array))
          errors += self.verify(r, check, checked)
        elsif ([String, Symbol].include? r.class)
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

  def self.match(key, config, list = nil)
    nil_allowed = false #TODO allow if conig matches :nil :nillable, etc
    return false if !list.nil? && !list.key_exists?(key) && !nil_allowed
    value = list.nil? ? key : list[key]
    return false; #TODO self.validate(value,config) ?
  end

  def self.generate(list, method = nil)
    return self._generate(list) if method.nil?
    generated_hash = {}
    hash.each do |k,v|
      generated_hash[k] = self._generate(method, v)
    end
    generated_hash
  #   @derived.each() do |d,f|
  #     if (self.fact?(f) && !self.fact?(d))
  #       @facts[d] = @facts[f]
  #       Vuppeteer::say("Setting derived fact #{d} from #{f}", :prep)
  #     elsif (!self.fact?(f))
  #       Vuppeteer::say("Cannot set derived fact #{d}, #{f} not set", :prep)
  #     else
  #       Vuppeteer::say("Skipping derived fact #{d}, already set", :prep)
  #     end
  #   end
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
      r = r.gsub(m, '__REDACTED_AS_SENSITIVE__')
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
  
    def self._generate(m, c = {})
      #Vuppeteer::trace('generate', m, c)
      if (m.is_a?(Hash))
        result = c
        m.each() do |k, v|
           result[k] = self._calculate(v, k)
        end
        return result
      end
      case m.respond_to?('to_sym') ? m.to_sym : nil
      when :random, nil
        self.rand(c)
      when :derived
        self._calculate(c)
      else
        self.rand(c)
      end
    end

    def self._calculate(m, k)
      #Vuppeteer::trace('calculate', m, k)
      return Vuppeteer::get_fact(m) if m.is_a?(String)
      return self._generate(m) if m.is_a?(Symbol)
      return self._generate(m[0], m[1..-1]) if m.is_a?(Array)
      if (m.is_a?(Hash))
        n = MrUtils::sym_keys(m)
        return self._generate(n.has_key?(:method) ? n[:method] : :random, m)
      end
      nil
    end

end