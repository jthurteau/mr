## 
# Encapsulates Vagrant Plugin management for VagrantManager
#

#TODO https://www.vagrantup.com/docs/vagrantfile/vagrant_settings.html

#TODO implement standard plugins
# vagrant-vbguest https://github.com/dotless-de/vagrant-vbguest
# vagrant-register? https://github.com/projectatomic/adb-vagrant-registration
module Plugin
  extend self

#  @x = ['never', 'always'][1]
  
  # def self.init()
  #   v = VagrantManager::get()
  #   if Vagrant.has_plugin?('vagrant-registration')
  #   #   v.registration.username = 'foo'
  #   #   v.registration.password = 'bar'
  #     v.registration.skip = true
  #     v.registration.unregister_on_halt = false
  #     #v.registration.name = host+app+developer?
  #   #config.registration.auto_attach = false # only do this on dev
  #   end
  # end

  # def self.managing?(what)
  #   return false if 'registration' != what
  #   return RhelManager.is_it?() && '8' == RhelManager::el_version() && RhelManager::ready_to_register()
  # end

  # def self.setup_registration()
  #   v = VagrantManager::get()
  #   mode = RhelManager::ready_to_register()
  #   if Vagrant.has_plugin?('vagrant-registration')
  #     if 'user' == mode
  #       v.registration.username = Vuppeteer::get_fact('rhsm_user')
  #       v.registration.password = Vuppeteer::get_fact('rhsm_pass')
  #     elsif 'org' == mode
  #       v.registration.org = Vuppeteer::get_fact('rhsm_org')
  #       v.registration.activationkey = Vuppeteer::get_fact('rhsm_key')
  #     end
  #     v.registration.skip = false
  #   #config.registration.auto_attach = false # only do this on dev
  #   end
  # end

end