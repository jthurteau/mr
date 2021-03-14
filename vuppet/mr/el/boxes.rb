## 
# Encapsulates software collection management for MrRogers
# NOTE: SCL seems to be deprecated with RHEL8? so this module may be replaces with one more focuses on Yum Modules?
#

module Boxes
  extend self

  @builds = {}
  @prototypes = {}

  def self.add(vm_name, conf_source)
    @builds[vm_name] = conf_source
  end 

  def self.proto(vm_name, conf_source)
    @prototypes[vm_name] = conf_source
  end 

  def self.include?(v)
    return @builds.has_key?(v)
  end

  ##
  # returns an array of matching vm_names
  def self.get(w = nil, prototypes = false)
    source = prototypes ? @prototypes : @builds
    #Vuppeteer::trace('vm options', source, @prototypes, @builds, w)
    return [source.keys()[0]] if (w.nil? || w == :all || w == :active) && source.length > 0
    return [w] if source.has_key?(w)
    return []
  end

  def self.all()
    return @builds.keys
  end

  def self.config(w, prototypes = false)
    source = prototypes ? @prototypes : @builds
    return source[w] if source.has_key?(w)
  end

  #################################################################
  private
  #################################################################

end