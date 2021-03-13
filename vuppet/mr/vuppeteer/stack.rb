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

  def self.get(options = false)
    if (options)
      extension_free = options.class === TrueClass || options.include?('-extensions')
      mixin_optional = !(options.class === TrueClass) && options.include?('+optional')
    else
      extension_free = true
      mixin_optional = false
    end
    search = mixin_optional ? (@ppp + Vuppeteer.get_fact('stack_optional', [])) : (@ppp)
    if (extension_free)
      extension_free = []
      search.each do |p|
        extension_free.push(p.split('.').first())
      end
      return extension_free
    end
    search
  end

  def self.add(items, after = true)
    items = MrUtils::enforce_enumerable(items)
    items.reverse!() if after.class == FalseClass
    after = (items.include?(after) ? items.index(after) : true) if ![TrueClass, FalseClass, Integer].include?(after.class)
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

#################################################################
  private
#################################################################



end