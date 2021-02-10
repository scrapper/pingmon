require 'uri'
require 'timers'

require 'pingmon/HTTPServer'
require 'pingmon/RRD'
require 'pingmon/models/HostGroups'
require 'pingmon/views/GraphPage'

module PingMon

  class PingMonitor

    # Number of pings in a sequence
    @@Pings = 5

    def initialize
      @db_dir = File.join(ENV['HOME'], '.pingmon')
      init
      read_config
      @rrd = RRD.new(@db_dir)
      @host_groups = HostGroups.new(@rrd, @config)
      @http_server = nil
    end

    def main(argv)
      threads = []

      @host_groups.each_host do |host|
        threads << Thread.new do
          timers = Timers::Group.new
          timers.now_and_every(host.ping_interval_secs) { ping(host.name) }
          loop { timers.wait }
        end
      end

      threads << Thread.new do
        @http_server = HTTPServer.new('vm1.infra', 3333)
        @http_server.add_route(:get, %w(pingmon), self, :pingmon)
        @http_server.add_route(:get, %w(chart), self, :chart)
        @http_server.run
      end

      threads.each { |thread| thread.join }
    end

    private

    def init
      unless Dir.exist?(@db_dir)
        $stderr.puts "Creating pingmon directory #{@db_dir}"
        Dir.mkdir(@db_dir)
      end
    end

    def read_config
      config_file = File.join(@db_dir, 'config.json')
      if File.exist?(config_file)
        @config = JSON.parse(File.read(config_file))
      else
        $stderr.puts "Config file #{config_file} is missing"
        exit 1
      end
    end

    def ping(host)
      packet_loss = 100.0
      round_trip_time = 'U'

      out = %x(ping -q -w 5 -W 10 -n -c #{@@Pings} #{host}).split("\n")

      if out[3] && /packets transmitted/ =~ out[3] &&
          (match = out[3].match(/.*, ([0-9]+)% packet loss.*/))
        packet_loss = match[1].to_f
      else
        $stderr.puts "Could not find packet loss: #{out[3]}"
      end

      if out[4] && /rtt min\/avg\/max\/mdev =/ =~ out[4]
        round_trip_time = out[4].match(/.*\/([0-9.]+)\/[0-9.]+\/.*/)[1].to_f
      end

      @rrd.add_values(host, round_trip_time, packet_loss)
    end

    def chart(args)
      unless args.include?('host')
        return HTTPServer::Response.new(406, 'Paramater "host" is missing')
      end
      host = args['host'].first
      unless @host_groups.known_hosts.include?(host)
        $stderr.puts "Unknown host #{host}"
        return HTTPServer::Response.new(406, "Unknown host #{host}")
      end

      duration = GraphPage::DURATIONS.first.value
      if args['duration']
        duration = args['duration'].first.to_i
        unless GraphPage::DURATIONS.find { |d| d.value == duration }
          $stderr.puts "Unsupported duration #{duration}"
          duration = GraphPage::DURATIONS.first.value
        end
      end

      body = @rrd.graph(host, duration)
      HTTPServer::Response.new(200, body, 'image/png')
    end

    def pingmon(args)
      page = GraphPage.new(@host_groups)

      HTTPServer::Response.new(200, page.render(args), 'text/html')
    end

  end

end
