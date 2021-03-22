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

require 'pingmon/controllers/DropdownMenu'

module PingMon

  class DropdownButton < DropdownMenu

    def initialize(label, base_url, argument_to_set)
      super(label, base_url, argument_to_set)
      @label = label
    end

    def select(item)
      @title = "#{@label}: #{item}"
    end

  end

end

