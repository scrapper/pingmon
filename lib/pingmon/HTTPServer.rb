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
require 'socket'
require 'cgi'
require 'base64'

module PingMon

  class HTTPServer

    class Request

      attr_reader :status, :message, :path, :method, :version, :headers, :body

      def initialize(status = 200, message = 'OK', path = '', method = '',
                     version = '1.0', headers = {}, body = '')
        @status = status
        @message = message
        @path = path
        @method = method
        @version = version
        @headers = headers
        @body = body
      end

    end

    class Response

      attr_reader :code, :body, :content_type

      def initialize(code, body = '', content_type = 'text/plain')
        @code = code
        @body = body
        @content_type = content_type
      end

    end

    class Route < Struct.new(:type, :path, :object, :method)
    end

    RESPONSE_MESSAGES = {
      200 => 'OK',
      400 => 'Bad Request',
      403 => 'Forbidden',
      404 => 'Not Found',
      405 => 'Method Not Allowed',
      406 => 'Not Acceptable',
      408 => 'Request Timeout',
      413 => 'Request Entity Too Large',
      500 => 'Internal Server Error'
    }

    attr_reader :port

    def initialize(hostname = 'localhost', port = 0)
      @hostname = hostname
      @port = port
      @terminate = false

      @routes = []
    end

    # Register a given method of a given object to be called whenever a
    # request of the given type is received with the given URL path.
    def add_route(type, path, object, method)
      unless %w( GET PUT POST ).include?(type)
        raise ArgumentError, "type must be either GET, PUT or POST"
      end

      @routes.delete_if { |r| r.type == type && r.path == path }
      @routes << Route.new(type, path, object, method)
    end

    def run
      server = TCPServer.new(@hostname, @port)
      # If requested port is 0, we have to determine the actual port.
      @port = server.addr[1] if @port == 0

      while !@terminate do
        begin
          @session = server.accept
          request = read_request
          if request.status >= 400
            send_response(Response.new(request.status))
            next
          end

          send_response(process_request(request))

          @session.close
          @session = nil

        rescue SystemExit, Interrupt
          $stderr.puts "Aborting on user request..."
          stop
        rescue IOError => e
          $stderr.puts "HTTPServer IOError: #{e.message}"
        end
      end
    end

    def stop
      @terminate = true
    end

    private

    def send_response(response)
      message = RESPONSE_MESSAGES[response.code] || 'Internal Server Error'

      http = "HTTP/1.1 #{response.code} #{message}\r\n" +
        "Content-Type: #{response.content_type}\r\n"
      unless response.body.empty?
        http += "Content-Length: #{response.body.bytesize}\r\n"
      end
      http += "Connection: close\r\n"

      unless response.body.empty?
        http += "\r\n#{response.body}"
      end

      @session.print(http)
    end

    def read_request
      # Read the first part of the request. It may be the only part.
      request = @session.readpartial(2048)

      # It must not be empty.
      if (lines = request.lines).empty?
        return Request.new(400)
      end

      method, path, version = request.lines[0].split
      # We only support GET POST and PUT requests
      unless method && %q( GET POST PUT ).include?(method)
        return Request.new(405)
      end

      headers = {}
      body = ''
      mode = :headers

      lines[1..-1].each do |line|
        if mode == :headers
          if line == "\r\n"
            # An empty line switches to body parsing mode.
            mode = :body
          else
            header, value = line.split
            if header.nil? || value.nil? || header.empty? || value.empty?
              next
            end
            header = header.gsub(':', '').downcase

            # Store the valid header
            headers[header] = value
          end
        else
          # Append the read line to the body.
          body += line
        end
      end

      content_length = 0
      if headers['content-length']
        content_length = headers['content-length'].to_i
        # We only support 65k long requests to prevent DOS attacks.
        if content_length > 2 ** 16
          return Request.new(413)
        end

        # We must receive the full requests within 5 seconds.
        timeout = Time.now + 5.0
        while Time.now < timeout && body.bytesize < content_length
          body += @session.readpartial(2048)
        end
      end
      body.chomp!

      # The request is only valid if the body length matches the content
      # length specified in the header.
      if body.bytesize != content_length
        return Request.new(408)
      end

      # Return the full request.
      Request.new(200, 'OK', path, method, version, headers, body)
    end

    def process_request(request)
      uri = URI("http://#{request.headers['host'] || 'localhost'}" +
                "#{request.path}")

      parameter = (query = uri.query) ? CGI.parse(query) : {}

      path = uri.path.split('/')
      path.shift

      if (route = @routes.find { |r| r.type == request.method &&
          r.path == path })
        response = route.object.send(route.method, parameter)
        return Response.new(response.code, response.body,
                            response.content_type)
      else
        return Response.new(404, "Path not found: #{uri.path}")
      end
    end

  end

end

