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

    # Supported HTTP request types.
    REQUEST_TYPES = %w( GET POST )

    MAX_CONTENT_LENGTH = 2 ** 16

    MESSAGE_CODES = {
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

    class Request

      attr_reader :code, :path, :method, :version, :headers, :body

      def initialize(path = '', method = '', version = '1.0', headers = {},
                     body = '')
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

    class Statistics

      attr_reader :requests, :errors

      def initialize
        @requests = Hash.new { |k, v| k[v] = 0 }
        @errors = Hash.new { |k, v| k[v] = 0 }
      end

    end

    attr_reader :port, :statistics

    def initialize(hostname = 'localhost', port = 0)
      @hostname = hostname
      @port = port
      @terminate = false

      @routes = {}
      @statistics = Statistics.new
    end

    # Register a given method of a given object to be called whenever a
    # request of the given type is received with the given URL path.
    def add_route(type, path, object, method)
      unless REQUEST_TYPES.include?(type)
        raise ArgumentError, "type must be either one of " +
          "#{REQUEST_TYPES.join(' ')}"
      end
      unless path.respond_to?(:each)
        raise ArgumentError, 'path must be an Enumerable'
      end
      path.each do |p|
        if p.include?('/')
          raise ArgumentError, 'path elements must not include a /'
        end
      end

      @routes[type + ':' + path.join('/')] =
        Route.new(type, path, object, method)
    end

    def run
      server = TCPServer.new(@hostname, @port)
      # If requested port is 0, we have to determine the actual port.
      @port = server.addr[1] if @port == 0

      while !@terminate do
        begin
          @session = server.accept
          request = read_request
          if request.is_a?(Response)
            # The request was faulty. Return an error.
            send_response(request)
            next
          end

          send_response(process_request(request))

          @session.close
          @session = nil

        rescue SystemExit, Interrupt
          $stderr.puts "Aborting on user request..."
          stop
        rescue IOError => e
          $stderr.puts "HTTPServer #{e.class}: #{e.message}"
        end
      end
    end

    def stop
      @terminate = true
    end

    private

    def send_response(response)
      message = MESSAGE_CODES[response.code] || 'Internal Server Error'

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
      request = read_with_timeout(2048, 0.01)

      # It must not be empty.
      if request.empty? || (lines = request.lines).length < 3
        return error(400, 'Request is empty')
      end

      method, path, version = request.lines[0].split
      # Ensure that the request type is supported.
      unless method && REQUEST_TYPES.include?(method)
        return error(405, "Only the following request methods are " +
                     "allowed: #{REQUEST_TYPES.join(' ')}")
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
        if content_length > MAX_CONTENT_LENGTH
          return error(413, "Content length must be smaller than " +
                       "#{MAX_CONTENT_LENGTH}")
        end

        body += read_with_timeout(content_length - body.bytesize, 5)
      end
      body.chomp!

      # The request is only valid if the body length matches the content
      # length specified in the header.
      if body.bytesize != content_length
        return error(408, "Request timeout. Body length " +
                     "(#{body.bytesize}) does not " +
                     "match specified content length (#{content_length})")
      end

      @statistics.requests[method] += 1

      # Return the full request.
      Request.new(path, method, version, headers, body)
    end

    def read_with_timeout(maxbytes, timeout_secs)
      str = ''

      deadline = Time.now - timeout_secs
      fds = [ @session ]
      while maxbytes > 0 && timeout_secs > 0.0
        if IO.select(fds, [], [], timeout_secs)
          # We only have one socket that we are listening on. If select()
          # fires with a true result, we have something to read from @session.
          begin
            s = @session.readpartial(maxbytes)
          rescue EOFError
            break
          end
          maxbytes -= s.bytesize
          str += s
          timeout_secs = deadline - Time.now
        else
          break
        end
      end

      str
    end

    def process_request(request)
      # Construct a dummy URI so we can use the URI class to parse the request
      # and extract the path and parameters.
      uri = URI("http://#{request.headers['host'] || 'localhost'}" +
                "#{request.path}")

      parameter = (query = uri.query) ? CGI.parse(query) : {}

      path = uri.path.split('/')
      path.shift

      if (route = @routes[request.method + ':' + path.join('/')])
        response = route.object.send(route.method, parameter)
        return Response.new(response.code, response.body,
                            response.content_type)
      else
        return error(404, "Path not found: #{uri.path}")
      end
    end

    def error(code, message)
      @statistics.errors[code] += 1
      Response.new(code, message)
    end

  end

end

