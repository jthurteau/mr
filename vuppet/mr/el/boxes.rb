## 
# Encapsulates software collection management for MrRogers
# NOTE: SCL seems to be deprecated with RHEL8? so this module may be replaces with one more focuses on Yum Modules?
#

module Boxes
  extend self

  @builds = {}

  def self.add(vm_name, conf_source)
    @builds[vm_name] = conf_source
  end 

  def self.include?(v)
    return @builds.has_key?(v)
  end

  def self.get()
    return @builds
  end

  #################################################################
  private
  #################################################################

end