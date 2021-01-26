require 'uri'

require 'pingmon/CommandParser'
require 'pingmon/HTTPServer'

module PingMon

  class PingMonitor

    @@ConsolidationSteps = 2
    @@PingInterval = 15
    @@Pings = 5

    def initialize
      @db_dir = File.join(ENV['HOME'], '.pingmon')
      @http_server = nil
    end

    def main(argv)
      cp = CommandParser.new('pingmon')

      cp.command('init', 'Initialize the RRD database') do
        init
      end
      cp.command('add', 'Add a new host to monitor') do |args|
        add_host(args.first)
      end
      cp.command('run', 'Run ping server') do
        run
      end

      cp.process(argv)
    end

    def process_get_request(session, request)
      uri = URI("http://#{request[:headers]['host'] || 'localhost'}" +
                "#{request[:path]}")

      params = (query = uri.query) ? CGI.parse(query) : {}

      empty, command, value = uri.path.split('/')

      unless empty && empty.empty? && command && !command.empty?
        send_response(session, 404, 'Not Found', uri.path)
        return
      end

      if command == 'chart'
        host = value
        body = graph(host, 12 * 60 * 60)
        send_response(session, 200, 'OK', body, 'image/png')
      elsif command == 'pingmon'
        send_response(session, 200, 'OK', graph_page, 'text/html')
      else
        send_response(session, 404, 'Not Found', uri.path)
      end
    end

    def process_post_request(session, request)
      send_response(session, 404, 'Not Found', request[:path])
    end

    def send_response(session, code, message, body, content_type = '')
      @http_server.send_response(session, code, message, body, content_type)
    end

    private

    def init
      unless Dir.exist?(@db_dir)
        $stderr.puts "Creating pingmon directory #{@db_dir}"
        Dir.mkdir(@db_dir)
      end
    end

    def add_host(name_or_ip)
      if known_hosts.include?(name_or_ip)
        $stderr.puts "RDD database for #{name_or_ip} already exists!"
        return
      end

      system(<<"EOT"
rrdtool create #{rrd_file(name_or_ip)} \
--step #{@@ConsolidationSteps * @@PingInterval} \
DS:pl:GAUGE:#{2 * @@ConsolidationSteps * @@PingInterval}:0:100 \
DS:rtt:GAUGE:#{2 * @@ConsolidationSteps * @@PingInterval}:0:10000000 \
RRA:MAX:0.5:1:#{24 * 60 * 60 / (@@PingInterval * @@ConsolidationSteps)}
EOT
            )
    end

    def run
      threads = []

      known_hosts.each do |host|
        threads << Thread.new do
          loop do
            ping(host)
            # A ping with 5 pings takes 4 seconds. 4 pings take 3 seconds.
            # Substract that from the overall interval.
            sleep(@@PingInterval - (@@Pings - 1))
          end
        end
      end

      threads << Thread.new do
        (@http_server = HTTPServer.new('vm1.infra', 3333)).run(self)
      end

      threads.each { |thread| thread.join }
    end

    def known_hosts
      rrd_files = Dir.glob(File.join(@db_dir, '*.rrd'))
      # Remove the .rrd extensions
      rrd_files.map { |f| File.basename(f)[0..-5] }
    end

    def rrd_file(host)
      File.join(@db_dir, host + '.rrd')
    end

    def ping(host)
      out = %x(ping -q -n -W 0.5 -c #{@@Pings} #{host}).split("\n")

      if out.length == 5
        if out[3] && /packets transmitted/ =~ out[3]
          packet_loss = out[3].match(/.*([0-9]+)%.*/)[1].to_f
        else
          $stderr.puts "Could not find packet loss: #{out[3]}"
          packet_loss = 100.0
        end

        if out[4] && /rtt min\/avg\/max\/mdev =/ =~ out[4]
          round_trip_time = out[4].match(/.*\/([0-9.]+)\/[0-9.]+\/.*/)[1].to_f
        else
          # In case we have 100% packet loss we don't have an rtt value.
          round_trip_time = 'U'
        end
      else
        $stderr.puts "Could not parse ping answer: #{out}"
        packet_loss = 100.0
        round_trip_time = 'U'
      end

      system("rrdtool update #{rrd_file(host)} --template pl:rtt N:" +
             "#{packet_loss}:#{round_trip_time}")
    end

    def graph_page
      html = <<"EOT"
<html>
  <head>
    <title>PingMon</title>
    <meta http-equiv=\"refresh\" content=\"30\">
  </head>
  <body>
EOT

      known_hosts.each do |host|
        html << "<div><img src=\"chart/#{host}\"/></div>\n"
      end

      html << <<"EOT"
  </body>
</html>
EOT
      html
    end

    def graph(host, duration)
      db = rrd_file(host)
      cmd = <<"EOT"
rrdtool graph - \
-w 1500 -h 80 -a PNG \
--slope-mode \
--start -#{duration} --end now \
--font DEFAULT:7: \
--title \"ping latency #{host}\" \
--watermark \"#{Time.now}\" \
--vertical-label 'latency (ms)' \
--right-axis-label 'latency (ms)' \
--lower-limit 0 \
--right-axis 1:0 \
--alt-y-grid --rigid \
DEF:roundtrip=#{db}:rtt:MAX \
DEF:packetloss=#{db}:pl:MAX \
CDEF:PLNone=packetloss,0,0,LIMIT,UN,UNKN,INF,IF \
CDEF:PL10=packetloss,1,20,LIMIT,UN,UNKN,INF,IF \
CDEF:PL25=packetloss,20,40,LIMIT,UN,UNKN,INF,IF \
CDEF:PL50=packetloss,40,60,LIMIT,UN,UNKN,INF,IF \
CDEF:PL100=packetloss,60,100,LIMIT,UN,UNKN,INF,IF \
LINE1:roundtrip#0000FF:'latency (ms)' \
GPRINT:roundtrip:LAST:'Cur\\: %5.2lf' \
GPRINT:roundtrip:AVERAGE:'Avg\\: %5.2lf' \
GPRINT:roundtrip:MAX:'Max\\: %5.2lf' \
GPRINT:roundtrip:MIN:'Min\\: %5.2lf\t\t\t' \
COMMENT:'pkt loss\\:' \
AREA:PLNone#FFFFFF:'0%':STACK \
AREA:PL10#FFFF00:'1-20%':STACK \
AREA:PL25#FFCC00:'20-40%':STACK \
AREA:PL50#FF8000:'40-60%':STACK \
AREA:PL100#FF0000:'60-100%':STACK
EOT
      %x( #{cmd} )
    end

  end

end
