## 
# Encapsulates helper provisioner management for Mr
#

module Helpers
  extend self

  @default_helpers = []
  @default_helpers_added = false

  @when_to_chill = ['never', 'always'][1]
  @when_to_nano_enforce = 'once'

  def self.setup(helpers = nil, vm = nil)
    helpers = Vuppeteer::get_fact('helpers') if helpers.nil?
    helpers = MrUtils::enforce_enumerable(helpers, false)
    default = !Vuppeteer::get_fact('disable_default_helpers', false)
    self._add(vm, helpers, !helpers && default) if helpers || default
  end

  #################################################################
  private
  #################################################################

  def self._add(vm, additional = [], default = false)
    Vuppeteer::trace('Setting up helpers', additional, default)
    if (!additional.nil?)
      additional.each do |a|
  #       if a.start_with?('scl+')
  #         rest = a.slice(4..-1)
  #         a = 'scl'
  #       end
        case a #TODO turn this in to a detector for scripts in /bash/helpers?
        when 'nano'  
          self.nano_please(vm)
        when 'os'
          self.os_friendly(vm)
        when 'composer'
          self.composer_please(vm)
        when 'net'
          self.net_please(vm)
  #       when 'scl'
  #         self.scl_enable(vm, rest)
        else
          Vuppeteer::say("Unknown helper: #{a}")
        end
      end
    end
    if (default && !@default_helpers_added)
      @default_helpers.each do |d|
  #     notices = Vuppeteer::pull_notices()
  #     vm.provision "reminders", type: :shell, run: 'always' do |s|
  #       s.inline = <<-SHELL
  #         echo 'To activate post-startup tasks on the guest VM use: vagrant [up|provision] --provision-with start'
  #         #{notices}
  #       SHELL
  #     end
  #     #TODO loop these from an array
        vm.provision "chill", type: :shell, run: @when_to_chill do |s|
          s.inline = FileManager::bash('helper_chill')
        end

        vm.provision "no-chill", type: :shell, run: @when_to_chill do |s|
          s.inline = FileManager::bash('helper_nochill')
        end

  #     vm.provision "start", type: :shell, run: 'never' do |s|
  #       s.inline = FileManager::bash('helper_start')
  #     end
    
  #     vm.provision "stop", type: :shell, run: 'never' do |s|
  #       s.inline = FileManager::bash('helper_stop')
  #     end

  #     vm.provision "restart", type: :shell, run: 'never' do |s|
  #       s.inline = FileManager::bash('helper_restart')
  #     end

  #     vm.provision "super-restart", type: :shell, run: 'never' do |s|
  #       s.inline = FileManager::bash('helper_super-restart')
  #     end

  #     vm.provision "project-clone", type: :shell, run: 'never' do |s|
  #       s.inline = FileManager::bash('helper_clone')
  #     end

  #     vm.provision "project-stash", type: :shell, run: 'never' do |s|
  #       s.inline = FileManager::bash('helper_stash')
  #     end

  #     vm.provision "project-restore", type: :shell, run: 'never' do |s|
  #       s.inline = FileManager::bash('helper_restore')
  #     end

      end
  #     #TODO? pass in @guest_path to merge changes to /vagrant/vuppet ??
      install_script = Vuppeteer::external? ? FileManager::bash('helper_install', FileManager::fs_view()) : "echo \"***Cannot install from an internal copy of MrRogers...\"\nexit 1" 
      vm.provision "mr-install", type: :shell, run: 'never' do |s|
        s.inline = install_script
      end
      uninstall_script = !Vuppeteer::external? ? FileManager::bash('helper_uninstall', FileManager::fs_view()) : "echo \"***MrRogers already uninstalled...\"\nexit 1" 
      vm.provision "mr-uninstall", type: :shell, run: 'never' do |s|
        s.inline = uninstall_script
      end
      @default_helpers_added = true
    end
  end

  def self.nano_please(vm)
    vm.provision "nano_setup", type: :shell do |s|
      s.inline = 'yum install nano -y'
    end
    vm.provision "nano_make_default", type: :shell, run: @when_to_nano_enforce do |s|
      s.inline = FileManager::bash('nano_enforce')
      s.privileged = false
    end
  end

  # def self.scl_enable(vm, package)
  #   vm.provision "scl+#{package}", type: :shell, run: @when_to_scl_enable do |s|
  #     s.inline = FileManager::bash('scl_enable', CollectionManager::package_view(package))
  #     s.privileged = false
  #   end
  # end

  def self.composer_please(vm)
    vm.provision "composer_setup", type: :shell do |s|
      s.inline = FileManager::bash('composer')
    end
  end

  def self.net_please(vm)
    vm.provision "network_setup", type: :shell do |s|
      s.inline = FileManager::bash('nettools')
    end
  end

  def self.os_friendly(vm)
    if Vagrant::Util::Platform.windows?
      self.windows_host_friendly(vm)
    end
  end

  def self.windows_host_friendly(vm)
    vm.provision "windows_support", type: :shell do |s|
      s.inline = FileManager::bash('windows_support')
      s.privileged = false
    end
  end

  # def self.update(vm)
    

  # end

end