## 
# Manages the Stack of recipes for Mr and Puppet to build
#

module Stack
  extend self

  @ppp = []

  def self.init()
    stack = Vuppeteer::get_fact('stack')
    if stack.nil?
      Vuppeteer::say('Warning: No stack provided in facts')
      return
    end
    stack.each do |s|
      next if !s || s.strip() == ''
      @ppp.push(s);
    end
    @ppp.unshift("project-#{Vuppeteer::get_fact('project')}") if Vuppeteer::fact?('project')
    @ppp.unshift("app-#{Vuppeteer::get_fact('app')}") if Vuppeteer::fact?('app')
  end

  def self.get(options = nil) #TODO the extention
    filter = []
    if (options.is_a?(Symbol) || options.is_a?(Array))
      options = MrUtils::enforce_enumerable(options)
      ignore_type = false
      mixin_optional = false
      base_name = true
      options.each() do |o|
        case o
        when :greedy
          ignore_type = true
        when :optional
          mixin_optional = true
        when :fact
          filter += ['facts/']
        when :manifest
          filter += ['manifest/']
        when :hiera
          filter += ['hiera/']
        when :full
          base_name = false
        end
      end
    else
      ignore_type = true
      mixin_optional = false
    end
    search = mixin_optional ? (@ppp + self.optional()) : (@ppp)
    if (filter.length > 0)
      search.filter!() {|s| !s.include?('/') || filter.any?() {|f| s.start_with?(f)}}
    end
    if (ignore_type)
      expanded = []
      search.each do |p|
        expanded.push(p.split('/', 2).last())
      end
      return expanded
    end
    base_name ? self._base(search) : search #TODO this may need cleanup w/expanded
  end

  def self.add(items, after = true)
    items = MrUtils::enforce_enumerable(items)
    items.reverse!() if after.is_a?(FalseClass)
    indexable = [TrueClass, FalseClass, Integer]
    after = (items.include?(after) ? items.index(after) : true) if !indexable.include?(after.class)
    items.each do |i|
      if (after.is_a?(TrueClass))
        @ppp.push(i)
      elsif !after.is_a?(FalseClass)
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