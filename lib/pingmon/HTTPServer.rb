require 'socket'
require 'cgi'
require 'base64'

module PingMon

  class HTTPServer

    attr_reader :port

    def initialize(hostname, port)
      @hostname = hostname
      @port = port
      @terminate = false
    end

    def run(initiator)
      @server = TCPServer.new(@hostname, @port)
      # If requested port is 0, we have to determine the actual port.
      @port = @server.addr[1] if @port == 0

      while !@terminate do
        begin
          session = @server.accept
          request = read_request(session)
          if request[:status] >= 400
            send_response(session, request[:status], request[:message])
            next
          end

          if request[:method] == 'POST'
            initiator.process_post_request(session, request)
          elsif request[:method] == 'GET'
            initiator.process_get_request(session, request)
          else
            send_response(session, 405, 'Method Not Allowed')
          end

          session.close

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

    def send_response(session, code, message, body = '',
                      content_type = 'text/plain')
      response = "HTTP/1.1 #{code} #{message}\r\n" +
        "Content-Type: #{content_type}\r\n"
      unless body.empty?
        response += "Content-Length: #{body.bytesize}\r\n"
      end
      response += "Connection: close\r\n"

      unless body.empty?
        response += "\r\n#{body}"
      end

      session.print(response)
    end

    private

    def read_request(session)
      # Read the first part of the request. It may be the only part.
      request = session.readpartial(2048)

      # It must not be empty.
      if (lines = request.lines).empty?
        return { status: 400, message: 'Bad Request' }
      end

      method, path, version = request.lines[0].split
      # We only support GET POST and PUT requests
      unless method && %q( GET POST PUT ).include?(method)
        return { status: 405, message: 'Method Not Allowed' }
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
        if content_length > 2 ** 32
          return { status: 413, message: 'Request Entity Too Large' }
        end

        # We must receive the full requests within 5 seconds.
        timeout = Time.now + 5.0
        while Time.now < timeout && body.bytesize < content_length
          body += session.readpartial(2048)
        end
      end
      body.chomp!

      # The request is only valid if the body length matches the content
      # length specified in the header.
      if body.bytesize != content_length
        return { status: 408, message: 'Request Timeout' }
      end

      # Return the full request.
      {
        status: 200,
        message: 'OK',
        path: path,
        method: method,
        version: version,
        headers: headers,
        body: body
      }
    end

  end

end

