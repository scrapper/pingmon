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

