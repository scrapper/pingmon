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
require 'optparse'

require 'pingmon/version'

module PingMon

  class CommandParser

    def initialize(name)
      @op = OptionParser.new do |opts|
        opts.banner = "Usage: #{name} <command> [options]"
        opts.separator ''
        opts.separator 'Commands:'
        opts.separator ''

        opts.on_tail('-h', '--help', 'Print this help') do
          puts opts
          exit(0)
        end
        opts.on_tail('-v', '--version', 'Print version information') do
          puts VERSION
          exit(0)
        end
      end

      @commands = {}
      @first_option = true
    end

    def command(name, description, &block)
      @commands[name] = block
      @op.separator "#{' ' * 4}#{name}#{' ' * (20 - name.length)}#{description}"
    end

    def option(name, description, &block)
      if @first_option
        @first_option = false
        @op.separator ''
        @op.separator 'Options:'
        @op.separator ''
      end

      @op.on(name, description, &block)
    end

    def process(argv)
      if (command = @op.parse!(argv).first) && @commands.include?(command)
        @commands[command].call(argv[1..-1])
      else
        $stderr.puts "ERROR: Unknown command '#{command}'!"
        puts
        puts @op
        exit(2)
      end
    end

  end

end

