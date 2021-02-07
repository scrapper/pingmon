module PingMon

  class Host

    attr_reader :name, :ping_interval_secs

    def initialize(name, ping_interval_secs)
      @name = name
      @ping_interval_secs = ping_interval_secs
    end

    def ensure_db_exists(rrd)
      unless rrd.exist?(@name)
        rrd.add_host(@name, @ping_interval_secs)
      end
    end

  end

end

