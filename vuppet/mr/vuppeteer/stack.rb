## 
# Manages the Stack of recipes for Mr and Puppet to build
#

module Stack
  extend self

  @ppp = []

  def self.init()
    stack = Vuppeteer::get_fact('stack')
    if stack.nil?
      Vuppeteer::shutdown('Error: No stack provided in facts')
    end
    #Vuppeteer::trace(stack,stack.class)
    stack.each do |s|
      next if !s || s.strip() == ''
      @ppp.push(s);
    end
  end

  def self.get(options = false) #TODO the extention
    filter = []
    if (options && !options.class == Symbol && !options.class == Array)
      extension_free = options.class === TrueClass || options.include?('-extensions')
      mixin_optional = !(options.class === TrueClass) && options.include?('+optional')
    elsif (options.class == Symbol || options.class == Array)
      options = MrUtils::enforce_enumerable(options)
      extension_free = false
      mixin_optional = false
      options.each() do |o|
        case o
        when :optional
          mixin_optional = true
        when :fact
          filter += ['facts/']
        when :manifest
          filter += ['manifest/']
        when :hiera
          filter += ['hiera/']
        end
      end
    else
      extension_free = true
      mixin_optional = false
    end
    search = mixin_optional ? (@ppp + self.optional()) : (@ppp)
    if (extension_free)
      extension_free = []
      search.each do |p|
        extension_free.push(p.split('.').first())
      end
      return extension_free
    end
    if (filter.length > 0)
      search.filter!() {|s| !s.include?('/') || filter.any() {|f| s.start_with?(f)}}
    end
    self._base(search)
  end

  def self.add(items, after = true)
    items = MrUtils::enforce_enumerable(items)
    items.reverse!() if after.class == FalseClass
    indexable = [TrueClass, FalseClass, Integer]
    after = (items.include?(after) ? items.index(after) : true) if !indexable.include?(after.class)
    items.each do |i|
      if (after.class == TrueClass)
        @ppp.push(i)
      elsif after.class != FalseClass
        @ppp.insert(after, *items)
      else
        @ppp.unshift(i)
      end
    end
  end

  def self.optional()
    Vuppeteer.get_fact('stack_optional', [])
  end

#################################################################
  private
#################################################################

  def self._base(stack)
    result = []
    stack.each() do |s|
      result.push(s.split('/')[-1])
    end
    result
  end

end