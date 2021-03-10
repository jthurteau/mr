## 
# Manages Host and Guest networking for MrRogers
# 1) inject host network identity in the guest to resolve various "containery" issues
# 2) setup the host so it can get around CORS when appropriate

module Network
  extend self
  
  require 'resolv'
  @hostname = nil
  @domain = nil
  @public_ip = nil
  @app = nil
  @developer = nil

  @host_passed = false 
  @cors_domain = nil

  @throttle = nil #<int, defaults to megabytes per second>[k|K|m|M|g|G]

  #TODO, support network throttling https://www.virtualbox.org/manual/ch06.html#network_bandwidth_limit

  def self.pass(trigger, vm)
    Puppeteer::say('Enabling NAT DNS Host Resolver for VirtualBox Guest Network 1','prep')
    vm.provider :virtualbox do |vb|
      #NOTE this runs once for each master image
      vb.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']
    end

    if (@throttle)
      Puppeteer::say("Throttling VirtualBox Guest Network 1 to #{@throttle}",'prep')
      vm.provider :virtualbox do |vb|
        vb.customize ['bandwidthctl', :id, 'add', 'Limit', '--type', 'network', '--limit', "#{@throttle}"]
        vb.customize ['modifyvm', :id, '--nicbandwidthgroup1', 'Limit']
      end
    end
    
    self._host_build(trigger)
    self.detect()
    trigger.before [:up, :provision, :reload] do |t|
      t.info = 'Harvesting Host FQDN'
      t.ruby do |env, machine|
        self.harvest_trigger()
      end
    end

    vm.provision 'set_hostname', type: :shell do |s|
      s.inline = ErBash::script('set_hostname', self.hostspec())
    end

    if (RhelManager::is_it?)
      vm.provision 'setup_domain', type: :shell do |s|
        s.inline = ErBash::script('setup_domain', self.hostspec())
      end
    end
    @host_passed = true
  end

  def self.passed?()
    @host_passed
  end

  def self.detect()
    begin
      fqdn = Socket.gethostbyname(Socket.gethostname).first.split('.')
    rescue
      fqdn = Socket.gethostname.split('.') #Sierra Mac bug, but may not work in some cases like VPN
    #TODO resque with fallback to org_domain?
    end
    hostname = fqdn.shift.downcase
    domain = fqdn.join('.').downcase
    public_ips = Socket.ip_address_list.reject{|i| !i.ipv4? || i.ipv4_loopback? || i.ipv4_multicast? || i.ipv4_private? }
    @public_ip = public_ips.any? ? public_ips.first&.ip_address : nil
    realfqdn = @public_ip ? (Resolv.getname @public_ip).split('.') : nil
    @hostname = realfqdn ? realfqdn.shift.downcase : hostname
    @domain = realfqdn ? realfqdn.join('.').downcase : domain
  end

  def self.host()
    return @hostname
  end

  def self.host_conf(app = nil, developer = nil)
    @app = app
    @developer = developer
  end

  def self.cors_set(cors)
    @cors_domain = cors
  end

  def self.throttle_set(bandwidth)
    @throttle = bandwidth
  end

  def self._host_build(trigger)
    #TODO map guest /etc/hosts 10.0.2.2        local hostname.domain alias ?
    return nil if (!@cors_domain) # nothing to do if we're not working around CORS
    base_host = (@app ? "#{@app}-" : 'local-')
    prefix = @developer ? "#{@developer}-" : ''
    trigger.before [:up, :provision, :reload, :resume] do |t|
      t.info = "Setting the stage..."
      t.ruby do |env, machine|
        self.etc_host(@cors_domain, prefix + base_host)
      end
    end
  end

  def self.domain()
    return @domain
  end

  def self.ip()
    return @public_ip ? @public_ip : ''
  end

  def self.harvest_trigger()
    if (!@public_ip)
      Puppeteer::say('Notice: No public IPv4 detected!')
      #Socket.ip_address_list.map{ |i| Puppeteer::say(i.inspect) }
    end
    public_ip_info = @public_ip ? " (#{@public_ip})" : ''
    Puppeteer::say("Host fqdn detected as #{@hostname} + #{@domain}#{public_ip_info}")
  end

  def self.etc_host(domain, host = 'local-dev', os = nil)
    #TODO set based on os
    etc_path = "C:\\Windows\\System32\\drivers\\etc\\hosts"
    if !File.file?(etc_path)
      Puppeteer::say("No etc host file found #{etc_path}")
    end
    etc_file_writable = false #File.writable_real?(etc_path)
    not_written = true
    #TODO windows in particular will return a false positive for writable? and writable_real?
    #in that case we will have to try-catch to detect (but only do that if windows host is detcted)

    # etc_file = nil
    # etc_file = File.new(etc_path, 'r')
    # ip4_entry = nil
    # ip4_managed = false
    # ip6_entry = nil
    # ip6_managed = false
    # while(etc_file.readline) |line|
    # #TODO scan the etc file, warn if no localhost mapping
    # end
    # if (!ip4_entry || !ip6_entry) {
    #   Vuppeteer::say("No localhost map your applicaiton #{etc_path}")
    # }
    if (etc_file_writable) 
      Puppeteer::say('The etc host file is writable')
      # FileUtils.cp etc_file, (etc_file + '.backup')
      # TODO add the #{@developer}-#{@app}.#{@domain} entry to the applicable lines if they are managed
      Puppeteer::say('...but this is not implemented yet.')
    else
      #TODO scan for unmanaged entries and append the #{@developer}-#{@app}.#{@domain} resolution
      Puppeteer::remember("Cannot edit the etc host file: #{etc_path}")
    end

    if (not_written) #TODO i think this output has been orphaned...
      Puppeteer::remember("You may add these entries manually:\n")
      Puppeteer::remember("127.0.0.1 #{host}.#{domain}")
      Puppeteer::remember("::1 #{host}.#{domain}\n")
      Puppeteer::remember('Your Vagrant/Puppet is available at:')
      Puppeteer::remember('localhost:8080')
    else
      Puppeteer::remember('Your Vagrant/Puppet is available at:')
      Puppeteer::remember('localhost:8080')
      Puppeteer::remember("#{host}.#{domain}:8080")
    end

  end

  def self.register(cors = false, app = nil, developer = nil)
    ## came from Mr
  #     NetworkManager::cors_set(cors) if cors
  #     app = Vuppeteer::get_fact('app', nil)
  #     developer = Vuppeteer::get_fact('developer', nil)
  #     unavailable_script = 'echo Unavailable in nomad mode'
  #     self._passthrough_host(app, developer) if (!NetworkManager::passed?) 
  #           s.inline = RhelManager::setup()
  end

  def self._passthrough_host(app = nil, developer = nil)
    NetworkManager::host_conf(app, developer)
    NetworkManager::pass(VagrantManager::config().trigger, VagrantManager::config().vm)
  end

  class Hostspec 
    @hostname = ''
    @domain = ''
    @public_ip = ''
    def initialize(h, d, i)
      @hostname = h
      @domain = d
      @public_ip = i ? i : '127.0.0.1'
    end
    def view()
      return binding()
    end
  end

  def self.hostspec()
    return Hostspec.new(@hostname, @domain, @public_ip).view()
  end
end