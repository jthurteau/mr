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
  
  def self.rand(conf)
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

  def self.generate(method, hash)
    generated_hash = {}
    hash.each do |k,v|
      generated_hash[k] = self._generate(method, v)
    end
    generated_hash
  #   @derived.each() do |d,f|
  #     if (self.fact?(f) && !self.fact?(d))
  #       @facts[d] = @facts[f]
  #       Puppeteer::say("Setting derived fact #{d} from #{f}", 'prep')
  #     elsif (!self.fact?(f))
  #       Puppeteer::say("Cannot set derived fact #{d}, #{f} not set", 'prep')
  #     else
  #       Puppeteer::say("Skipping derived fact #{d}, already set", 'prep')
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
  
    def self._generate(method, config)
      case method
      when :random, 'random'
        self.rand(config)
      end
    end

end