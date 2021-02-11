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

  class DropdownMenu

    class Item < Struct.new(:text, :value)
    end

    def initialize(title, base_url, argument_to_set)
      @base_url = base_url
      @argument_to_set = argument_to_set
      @title = title
      @items = []
    end

    def add_item(text, value = text)
      @items << Item.new(text, value)
    end

    def to_html(args)
      new_args = args.clone
      html = <<EOT
<div class="dropdown">
  <button class="dropdown_button">#{@title} ▼</button>
  <div class="dropdown_content">
EOT
      @items.each do |item|
        new_args[@argument_to_set] = item.value
          html << "<a href=\"#{@base_url}?" +
            "#{URI.encode_www_form(new_args)}\">#{item.text}</a>\n"
      end

      html += <<EOT
  </div>
</div>
EOT
    end

    def self.css
      <<EOT
.dropdown_button {
  background-color: #4CAF50;
  color: white;
  padding: 11px;
  font-size: 16px;
  border: none;
  cursor: pointer;
}

/* The container <div> - needed to position the dropdown content */
.dropdown {
  position: relative;
  display: inline-block;
}

/* Dropdown Content (Hidden by Default) */
.dropdown_content {
  display: none;
  position: absolute;
  background-color: #f9f9f9;
  min-width: 160px;
  box-shadow: 0px 8px 16px 0px rgba(0,0,0,0.2);
  z-index: 1;
  text-align: left;
}

/* Links inside the dropdown */
.dropdown_content a {
  color: black;
  padding: 12px 16px;
  text-decoration: none;
  display: block;
}

/* Change color of dropdown links on hover */
.dropdown_content a:hover {
  background-color: #dadada
}

/* Show the dropdown menu on hover */
.dropdown:hover .dropdown_content {
  display: block;
}

/* Change the background color of the dropdown button when the dropdown content is shown */
.dropdown:hover .dropdown_button {
  background-color: #3e8e41;
}
EOT
    end

  end

end

