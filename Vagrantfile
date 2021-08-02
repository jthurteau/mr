# -*- mode: ruby -*-
# vi: set ft=ruby :
##
# find the vuppeteer script
vuppeteer = 'vuppet/mr' # default path
vuppeteer_order = [vuppeteer, "../mr/#{vuppeteer}"] # where to look, i.e. internal then external
vuppeteer_order.each {|v| require_relative v if !defined?(Mr) && File.exist?("#{v}.rb")}
raise 'Unable to build Local Development Environment. Vuppeteer unavailable.' if !defined?(Mr)

#options = nil 
options = { # https://github.com/jthurteau/mr/wiki/Managing-Mr-from-the-Vagrantfile
  assert: {'project' => 'daniel',}, # see also /vuppet/vuppeteer.yaml
  stack: [
    'app-test', 
    'your-org', #'apache_php_multiviews_starterapp', 'sample_docroot',
  ],
  #debug: true,
  facts: {
    'debug' => true,
  },
  load_developer_facts: true,
  require: ['developer', 'db_password'],
  generated: {'db_password' => {'length' => 32, 'set' => :alnum, 'sensitive' => true},'a' => 'c'}
}

Vagrant.configure('2') do |v|
  # defaults to building with options + vuppet/vuppeteer.yaml + vuppet/local-dev.vuppeteer.yaml
  Mr::vagrant(v, options)
  ## provisioners, optionally run additional provisioners before puppet
  # example : v.vm.provision "shell", inline: "echo Hello, World"
  # example : Mr::add_provisioner('name'[, hash, when])
  Mr::puppet_apply()
  ## custom post puppetization provisioning can happen here
  # example : v.vm.provision "shell", inline: "echo Goodbye, World"
  # example : Mr::add_provisioner('name'[, hash, when])
  Mr::helpers()
end