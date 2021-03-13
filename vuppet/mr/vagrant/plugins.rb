## 
# Encapsulates Vagrant Plugin management for VagrantManager
#

#TODO https://www.vagrantup.com/docs/vagrantfile/vagrant_settings.html

#TODO implement standard plugins
# vagrant-vbguest https://github.com/dotless-de/vagrant-vbguest
# vagrant-register? https://github.com/projectatomic/adb-vagrant-registration

module Plugins
  extend self

  @plugins = {
    registration: {
      name: 'vagrant-registration'
    },
  }
#  @x = ['never', 'always'][1]
  
  def self.init()
    v = VagrantManager::get()
    if Vagrant.has_plugin?(@plugins[:registration][:name])
      v.registration.skip = true
      v.registration.unregister_on_halt = false
    end
  end

  def self.managing?(what)
    return false if !@plugins.has_key?(what)
    case what
    when :registration
      return ElManager.is_it?() && '8' == ElManager::el_version() && ElManager::ready_to_register()
    end
  end

  def self.setup(what)
    return if !@plugins.has_key?(what) || Vagrant.has_plugin?(@plugins[what][:name])
    v = VagrantManager::get()
    case what
    when :registration
      p =  v.registration 
      ElManager::configure_plugin(what, p)
    end
  end

end