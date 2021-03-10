## 
# Manages Triggers for VagrantManager
#

module Triggers
  extend self

  @map = {
    before: {
      up: [:before_up, :prep, :start],
      provision: [:before_provision, :prep, :start],
      reload: [:before_reload, :prep, :start],
      halt: [:halt],
      ssh: [:ssh, :ready],
    },
    after: {
      up: [:after_up, :ready],
      provision: [:after_provision, :ready],
      reload: [:after_reload, :ready]
    }
  }

  @notices = {
    before: {
      up: [],
      provision: [],
      reload: [],
      halt: [],
      ssh: [],
    }, 
    after: {
      up: [],
      provision: [],
      reload: [],
    }
  }

  @triggered = []
  @registered = false

  def self.triggered()
      @triggered.clone
  end

  def self.triggered?(t)
    @triggered.include?(t)
  end
    
  # def self.add(v, t)
    
  # end

  def self.register!(v)
    return if(@registered)
    v.trigger.before [:up] do |trigger|
      trigger.ruby do |env, machine|
        @notices[:before][:up].each {|n| print n}
        @map[:before][:up].each {|m| @triggered.push(m)}
      end
    end
    v.trigger.after [:up] do |trigger|
      trigger.ruby do |env, machine|
        @notices[:after][:up].each {|n| print n}
        @map[:after][:up].each {|m| @triggered.push(m)}
      end
    end
    v.trigger.before [:provision] do |trigger|
      trigger.ruby do |env, machine|
        @notices[:before][:provision].each {|n| print n}
        @map[:before][:provision].each {|m| @triggered.push(m)}
      end
    end
    v.trigger.after [:provision] do |trigger|
      trigger.ruby do |env, machine|
        @notices[:after][:provision].each {|n| print n}
        @map[:after][:provision].each {|m| @triggered.push(m)}
      end
    end
    v.trigger.before [:reload] do |trigger|
      trigger.ruby do |env, machine|
        @notices[:before][:reload].each {|n| print n}
        @map[:before][:reload].each {|m| @triggered.push(m)}
      end
    end
    v.trigger.after [:reload] do |trigger|
      trigger.ruby do |env, machine|
        @notices[:after][:reload].each {|n| print n}
        @map[:after][:reload].each {|m| @triggered.push(m)}
      end
    end
    v.trigger.before [:halt] do |trigger|
      trigger.ruby do |env, machine|
        @notices[:before][:halt].each {|n| print n}
        @map[:before][:halt].each {|m| @triggered.push(m)}
      end
    end
    v.trigger.before [:ssh] do |trigger|
      trigger.ruby do |env, machine|
        @notices[:before][:ssh].each {|n| print n}
        @map[:before][:ssh].each {|m| @triggered.push(m)}
      end
    end
    @registered = true
  end

  def self.store_say(s, t)
    case t
    when :before_up
      @notices[:before][:up].push(s)
    when :after_up
      @notices[:after][:up].push(s)
    when :halt
      @notices[:before][:halt].push(s)
    when :before_provision
      @notices[:before][:provision].push(s)
    when :after_provision
      @notices[:after][:provision].push(s)
    when :before_reload
      @notices[:before][:reload].push(s)
    when :after_reload
      @notices[:after][:reload].push(s)
    when :ssh
      @notices[:before][:ssh].push(s)
    when :prep
      @notices[:before][:up].push(s)
      @notices[:before][:provision].push(s)
      @notices[:before][:reload].push(s)
    when :start
      @notices[:before][:up].push(s)
      @notices[:before][:provision].push(s)
      @notices[:before][:reload].push(s)
      @notices[:before][:ssh].push(s)
    when :ready
      @notices[:after][:up].push(s)
      @notices[:after][:provision].push(s)
      @notices[:after][:reload].push(s)
    end
  end

end