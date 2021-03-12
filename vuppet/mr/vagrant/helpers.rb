## 
# Encapsulates helper provisioner management for Mr
#

module Helpers
  extend self

  # @when_to_chill = ['never', 'always'][1]
  # @when_to_nano_enforce = 'once'
  # @when_to_scl_enable = 'once'
  # @default_helpers_added = false

    def self.setup(vm = nil)
    vm = VagrantManager::config().vm if vm.nil?
    ##NOTE this was from old Mr class::_post_puppet before calling this method, didn't seem to provide useful debugging
    ## this particular method needed to always come after puppet, so as coded it wouldn't work with --provision-with
    #     if !@puppet_opt['catalog'].nil? && @puppet_opt['catalog']
    #       temp_path = FileManager::path(:temp)
    #       temp_state_path = "#{Mr::active_path()}/#{temp_path}state"
    #       FileManager::path_ensure(temp_state_path, true)
    #       remote = @state_path
    #       local = "#{@puppet_file_path}/#{temp_path}state"
    #       result_files = ['classes.txt', 'last_run_report.yaml', 'last_run_summary.yaml', 'resources.txt', 'state.yaml']
    #       FileManager::mirror_provisioner(remote, local, result_files, 'puppet-report')
    #     end
    helpers = Vuppeteer::get_fact('helpers')
    helpers = [helpers] if helpers && !helpers.class.include?(Enumerable)
    if (helpers || !Vuppeteer::get_fact('disable_default_hepers', false)) 
      self.add_helpers(vm, helpers, !PuppVuppeteeretFacts::get('disable_default_hepers', false))
    end
  end

  # def self.nano_please(vm)
  #   vm.provision "nano_setup", type: :shell do |s|
  #     s.inline = 'yum install nano -y'
  #   end
  #   vm.provision "nano_make_default", type: :shell, run: @when_to_nano_enforce do |s|
  #     s.inline = ErBash::script('nano_enforce')
  #     s.privileged = false
  #   end
  # end

  # def self.scl_enable(vm, package)
  #   vm.provision "scl+#{package}", type: :shell, run: @when_to_scl_enable do |s|
  #     s.inline = ErBash::script('scl_enable', CollectionManager::package_view(package))
  #     s.privileged = false
  #   end
  # end

  # def self.composer_please(vm)
  #   vm.provision "composer_setup", type: :shell do |s|
  #     s.inline = ErBash::script('composer')
  #   end
  # end

  # def self.net_please(vm)
  #   vm.provision "network_setup", type: :shell do |s|
  #     s.inline = ErBash::script('nettools')
  #   end
  # end

  # def self.os_friendly(vm)
  #   if Vagrant::Util::Platform.windows?
  #     self.windows_host_friendly(vm)
  #   end
  # end

  # def self.windows_host_friendly(vm)
  #   vm.provision "windows_support", type: :shell do |s|
  #     s.inline = ErBash::script('windows_support')
  #     s.privileged = false
  #   end
  # end

  # def self.update(vm)
    

  # end

  # def self.add_helpers(vm, additional = [], default = true)
  #   if (!additional.nil?)
  #     additional.each do |a|
  #       if a.start_with?('scl+')
  #         rest = a.slice(4..-1)
  #         a = 'scl'
  #       end
  #       case a #TODO turn this in to a detector for scripts in /bash/helpers?
  #       when 'nano'  
  #         self.nano_please(vm)
  #       when 'os'
  #         self.os_friendly(vm)
  #       when 'composer'
  #         self.composer_please(vm)
  #       when 'net'
  #         self.net_please(vm)
  #       when 'scl'
  #         self.scl_enable(vm, rest)
  #       else
  #         Vuppeteer::say("Unknown helper: #{a}")
  #       end
  #     end
  #   end
  #   if (default && !@default_helpers_added)
  #     notices = Vuppeteer::pull_notices()
  #     vm.provision "reminders", type: :shell, run: 'always' do |s|
  #       s.inline = <<-SHELL
  #         echo 'To activate post-startup tasks on the guest VM use: vagrant [up|provision] --provision-with start'
  #         #{notices}
  #       SHELL
  #     end
  #     #TODO loop these from an array
  #     vm.provision "chill", type: :shell, run: @when_to_chill do |s|
  #       s.inline = ErBash::script('helper_chill')
  #     end

  #     vm.provision "start", type: :shell, run: 'never' do |s|
  #       s.inline = ErBash::script('helper_start')
  #     end
    
  #     vm.provision "stop", type: :shell, run: 'never' do |s|
  #       s.inline = ErBash::script('helper_stop')
  #     end

  #     vm.provision "restart", type: :shell, run: 'never' do |s|
  #       s.inline = ErBash::script('helper_restart')
  #     end

  #     vm.provision "super-restart", type: :shell, run: 'never' do |s|
  #       s.inline = ErBash::script('helper_super-restart')
  #     end

  #     vm.provision "project-clone", type: :shell, run: 'never' do |s|
  #       s.inline = ErBash::script('helper_clone')
  #     end

  #     vm.provision "project-stash", type: :shell, run: 'never' do |s|
  #       s.inline = ErBash::script('helper_stash')
  #     end

  #     vm.provision "project-restore", type: :shell, run: 'never' do |s|
  #       s.inline = ErBash::script('helper_restore')
  #     end

  #     #TODO pass in @puppet_file_path to merge changes to /vagrant/puppet
  #     install_script = Vuppeteer::external? ? ErBash::script('helper_install', FileManager::fs_view()) : "echo \"***Cannot install from an internal copy of MrRogers...\"\nexit 1" 
  #     vm.provision "mr-install", type: :shell, run: 'never' do |s|
  #       s.inline = install_script
  #     end
  #     uninstall_script = !Vuppeteer::external? ? ErBash::script('helper_uninstall', FileManager::fs_view()) : "echo \"***MrRogers already uninstalled...\"\nexit 1" 
  #     vm.provision "mr-uninstall", type: :shell, run: 'never' do |s|
  #       s.inline = uninstall_script
  #     end
  #     @default_helpers_added = true
  #   end
  # end


end