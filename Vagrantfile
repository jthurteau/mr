# -*- mode: ruby -*-
# vi: set ft=ruby :
##
# find the vuppeteer script
vuppeteer = 'vuppet/mr' # default path
vuppeteer_order = [vuppeteer, '../mr/' + vuppeteer] # where to look, i.e. internal then external
vuppeteer_order.each {|v| require_relative v if !defined?(Mr) && File.exist?("#{v}.rb")}
raise 'Unable to build Local Development Environment. Vuppeteer unavailable.' if !defined?(Mr)

# options = { 
#     'assert' => {'project' => 'your-app-name',}, # see also /vuppet/project.yaml
#     stack: [
#       'app-user', 
#       'your-org', #'apache_php_multiviews_starterapp', 'sample_docroot',
#     ],
#     facts: {'a' => 'b'},
#     require: ['developer', 'db_password'],
#     generated: {'app_db_password' => {'length' => 32, 'set' => :alnum,}}
#   }

options = nil #{ # https://github.com/jthurteau/mr/wiki/Managing-MrRogers-from-the-Vagrantfile
#   assert: {'project' => 'your-app-name',}, # see also /vuppet/project.yaml
#   stack: [
#     'app-user', 
#     'your-org', #'apache_php_multiviews_starterapp', 'sample_docroot',
#   ],
#   require: ['developer', 'db_password'],
#   generated: {'app_db_password' => {'length' => 32, 'set' => :alnum,}}
# }

Vagrant.configure('2') do |v|
  # defaults to building with options + vuppet/project.yaml + vuppet/local-dev.project.yaml
  Mr::vagrant(v, options)
  ## provisioners, optionally run additional provisioners before puppet
  # example : v.vm.provision "shell", inline: "echo Hello, World"
  # example : Mr::add_provisioner('name'[, hash, when])
  Mr::puppet_apply()
  ## custom post puppetization provisioning can happen here
  # example : v.vm.provision "shell", inline: "echo Goodbye, World"
  # example : Mr::add_provisioner('name'[, hash, when])
end