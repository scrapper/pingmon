require 'pingmon/models/Host'

module PingMon

  class HostGroup

    attr_reader :name, :hosts

    def initialize(name, hosts)
      @name = name
      @hosts = []

      hosts.each do |host|
        @hosts << Host.new(host['name'], host['ping_interval_secs'] || 15)
      end
    end

  end

end

