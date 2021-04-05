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
      name: 'vagrant-registration' #NOTE optional unless you use vbguest plugin with RHEL8, Mr can handle registration otherwise
    },
    vbguest: {
      name: 'vbguest' #NOTE for RHEL8 you must have vagrant-registration (and let it register) for the vbguest plugin to work
    },
  }
#  @x = ['never', 'always'][1]
  
  def self.init()
    v = VagrantManager::get()
    if (Vagrant.has_plugin?(@plugins[:registration][:name]) && Mr::enabled?)
      v.registration.skip = true
      v.registration.unregister_on_halt = false
    end
  end

  def self.managing?(plugin, what = :default)
    return false if !@plugins.has_key?(plugin)
    #Vuppeteer::trace('testing plugin', plugin, what, ElManager.is_it?(what), ElManager::el_version(what), '8' == ElManager::el_version(what), ElManager::ready_to_register(what))
    case plugin
    when :registration
      return ElManager.use_registration_plugin(what) # && ElManager::ready_to_register(what)
    end
    false
  end

  def self.setup(what, which)
    #Vuppeteer.trace('testing plugin compatability', what, which, @plugins, @plugins[what],@plugins[what][:name],Vagrant.has_plugin?(@plugins[what][:name]))
    if !@plugins.has_key?(what) || !Vagrant.has_plugin?(@plugins[what][:name])
      Vuppeteer::say("Notice: attempting to setup unregistered plugin: #{what.to_s}")
      return
    end
    case what
    when :registration
      p =  VagrantManager::get().registration 
      ElManager::configure_plugin(what, p, which)
    end
  end

end