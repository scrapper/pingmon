require 'json'

require 'pingmon/models/HostGroup'

module PingMon

  class HostGroups

    attr_reader :groups

    def initialize(rrd, config)
      @rrd = rrd

      @groups = []
      config['host_groups'].each do |group|
        @groups << HostGroup.new(group['name'], group['hosts'])
      end

      check_host_dbs
    end

    def known_hosts
      @groups.map { |g| g.hosts.map { |h| h.name } }.flatten
    end

    def each_host
      @groups.each { |g| g.hosts.each { |h| yield(h) } }
    end

    private

    def check_host_dbs
      each_host do |h|
        h.ensure_db_exists(@rrd)
      end
    end

  end

end

