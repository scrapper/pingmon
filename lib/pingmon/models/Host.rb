#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = PingMon - A latency monitor
#
# Copyright (c) 2021 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
module PingMon

  class Host

    attr_reader :name, :common_name, :ping_interval_secs

    def initialize(name, common_name, ping_interval_secs)
      @name = name
      @common_name = common_name
      @ping_interval_secs = ping_interval_secs
    end

    def ensure_db_exists(rrd)
      unless rrd.exist?(@name)
        rrd.add_host(@name, @ping_interval_secs)
      end
    end

  end

end

