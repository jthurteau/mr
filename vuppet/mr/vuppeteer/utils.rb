## 
# Utils for Vuppeteer
#

module VuppeteerUtils
  extend self

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
  
  def self.rand(conf = {})
    length = conf&.dig('length')
    length = 16 if length.nil? || length < 1
    set = conf&.has_key?('set') ? conf['set'] : :alnum
    if (set.class == Symbol)
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
    self.random_string(set, length)
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

  def self.sensitive_facts()
    ['*_pat','*_pass', '*_password', '*_key', '*_secret']
  end

  def self.valid?(v, criteria = nil)
    return false
  end

  def self.storable?(method)
    return false
  end

  def self.verify(list, check, checked = [])
    Vuppeteer::trace(list, list.class, check, checked)
    errors = []
    list.each do |r|
        if (r.class == Hash)
          r.each do |k, v|
            result = check.has_key?(k) && v == check[k] #Facts::get(k) != v
            # raise "Error: duplicate conflicting assert for #{k}." if
            errors.push("Error: missing asserted fact, does not match expected value \"#{v}\" during boxing") if !result && !check.has_key?(k)
            errors.push("Error: fact \"#{k}\" does not match expected value \"#{v}\" during boxing") if !result && check.has_key?(k)
            checked.push(k)
          end
        elsif (r.class == Array)
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
  #       Vuppeteer::say("Setting derived fact #{d} from #{f}", 'prep')
  #     elsif (!self.fact?(f))
  #       Vuppeteer::say("Cannot set derived fact #{d}, #{f} not set", 'prep')
  #     else
  #       Vuppeteer::say("Skipping derived fact #{d}, already set", 'prep')
  #     end
  #   end
  end

  def self.filter_sensitive(s)
    return self.filter_sentitive_string(s) if s.class = String
    r = s.class.new
    s.each do |k,v| 
      if(v.class == String)
        r[k] = self.filter_sentitive_string(v)
      else
        r[k] = v.class.include?(Enumerable) ? self.filter_sensitive(v) : v
      end
    end
    r
  end

  def self.filter_sentitive_string(s)
    r = s.clone
    @sensitive.each do |f|
      r = r.gsub(f, '__REDACTED_AS_SENSITIVE__')
    end
    r
  end

  #################################################################
  private
  #################################################################
  
    def self._generate(m, c = {})
      Vuppeteer::trace('generate', m, c)
      if (m.class == Hash)
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
      Vuppeteer::trace('calculate', m, k)
      return Vuppeteer::get_fact(m) if m.class == String
      return self._generate(m) if m.class == Symbol
      return self._generate(m[0], m[1..-1]) if m.class == Array
      if (m.class == Hash)
        n = MrUtils.sym_keys(m)
        return self._generate(n.has_key?(:method) ? n[:method] : :random, m)
      end
      nil
    end

end