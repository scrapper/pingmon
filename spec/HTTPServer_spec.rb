require 'socket'
require 'net/http'
require 'uri'

require 'pingmon/HTTPServer'

describe PingMon::HTTPServer do

  it 'should create a server and stop it again' do
    start_server
    stop_server
  end

  it 'should respond to a http GET request' do
    start_server

    class TestPage
      def render(args)
        PingMon::HTTPServer::Response.new(200, 'Hello, world!')
      end
    end

    tp = TestPage.new
    @srv.add_route('GET', %w( hello ), tp, :render)
    response = Net::HTTP.get(URI("http://localhost:#{@srv.port}/hello"))
    expect(response).to eql('Hello, world!')
    expect(@srv.statistics.requests['GET']).to eql(1)

    stop_server
  end

  it 'should error on empty requests' do
    messages = [ [ "\n" ] ]

    responses = exchange_messages(messages)
    # Body starts at line 5
    expect(responses.first.split("\r\n")[5]).to eql('Request is empty')
    expect(@srv.statistics.errors[400]).to eql(1)
  end

  it 'should error on unknown route' do
    start_server

    response = Net::HTTP.get(URI("http://localhost:#{@srv.port}"))
    expect(response).to eql('Path not found: /')
    expect(@srv.statistics.errors[404]).to eql(1)

    stop_server
  end

  it 'should error on bad method' do
    messages = [
      [ <<"EOT"
HONK /foo/bar/ HTTP/1.1
HOST: hostname
Connection: Close
Content-Type: application/x-www-form-urlencoded
Content-Length: 7

a=b&c=d
EOT
      ]
    ]
    responses = exchange_messages(messages)
    expect(@srv.statistics.errors[405]).to eql(1)
  end

  it 'should error on too large content length' do
    messages = [
      [ <<"EOT"
POST /foo/bar/ HTTP/1.1
HOST: hostname
Connection: Close
Content-Type: application/x-www-form-urlencoded
Content-Length: 999999

a=b&c=d
EOT
      ]
    ]
    responses = exchange_messages(messages)
    expect(@srv.statistics.errors[413]).to eql(1)
  end

  it 'should error on content length not matching body size' do
    messages = [
      [ <<"EOT"
POST /foo/bar/ HTTP/1.1
HOST: hostname
Connection: Close
Content-Type: application/x-www-form-urlencoded
Content-Length: 999

a=b&c=d
EOT
      ]
    ]
    responses = exchange_messages(messages)
    expect(@srv.statistics.errors[408]).to eql(1)
  end

  #
  # Utility methods
  #
  def exchange_messages(messages, argv = %w(run))
    start_server

    responses = []
    messages.each do |message|
      sock = TCPSocket.new('localhost', @srv.port)
      message.each do |section|
        sock.print(section.gsub(/\n/, "\r\n"))
        responses << sock.readpartial(2048)
      end
    end

    stop_server

    responses
  end

  def start_server
    @srv = PingMon::HTTPServer.new
    @thr = Thread.new do
      @srv.run
    end

    sleep(1)
  end

  def stop_server
    @srv.stop

    sock = TCPSocket.new('localhost', @srv.port)
    sock.puts "\r\n\r\n"
    sock.close
    @thr.join
  end

end

