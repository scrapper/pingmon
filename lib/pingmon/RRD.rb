module PingMon

  class RRD

    def initialize(db_dir)
      @db_dir = db_dir
    end

    def add_host(host_name, ping_interval_secs)
      if File.exist?(rrd_file(host_name))
        $stderr.puts "RDD database for #{host_name} already exists!"
        return
      end

      $stderr.puts("Creating RRD file for #{host_name}")

      system(<<"EOT"
rrdtool create #{rrd_file(host_name)} \
--step #{ping_interval_secs} \
DS:pl:GAUGE:#{4 * ping_interval_secs}:0:100 \
DS:rtt:GAUGE:#{4 * ping_interval_secs}:0:10000000 \
RRA:MAX:0.5:1:#{24 * 60 * 60 / ping_interval_secs} \
RRA:MAX:0.5:#{5 * 60 / ping_interval_secs}:#{12 * 24 * 365}
EOT
            )
    end

    def exist?(host_name)
      File.exist?(rrd_file(host_name))
    end

    def add_values(host_name, round_trip_time, packet_loss)
      system("rrdtool update #{rrd_file(host_name)} --template pl:rtt N:" +
             "#{packet_loss}:#{round_trip_time}")
    end

    def graph(host_name, duration)
      db = rrd_file(host_name)
      cmd = <<"EOT"
rrdtool graph - \
-w 1500 -h 80 -a PNG \
--slope-mode \
--start -#{duration} --end now \
--font DEFAULT:7: \
--font TITLE:9: \
--title '#{host_name}' \
--watermark '#{Time.now}' \
--vertical-label 'Latency (ms)' \
--right-axis-label 'Latency (ms)' \
--lower-limit 0 \
--right-axis 1:0 \
--alt-y-grid --rigid \
DEF:roundtrip=#{db}:rtt:MAX \
DEF:packetloss=#{db}:pl:MAX \
CDEF:PLNone=packetloss,0,0,LIMIT,UN,UNKN,INF,IF \
CDEF:PL20=packetloss,1,20,LIMIT,UN,UNKN,INF,IF \
CDEF:PL40=packetloss,20,40,LIMIT,UN,UNKN,INF,IF \
CDEF:PL60=packetloss,40,60,LIMIT,UN,UNKN,INF,IF \
CDEF:PL100=packetloss,60,100,LIMIT,UN,UNKN,INF,IF \
LINE1:roundtrip#0000FF:'Latency (ms)' \
GPRINT:roundtrip:LAST:'Cur\\: %5.2lf' \
GPRINT:roundtrip:MIN:'Min\\: %5.2lf' \
GPRINT:roundtrip:AVERAGE:'Avg\\: %5.2lf' \
GPRINT:roundtrip:MAX:'Max\\: %5.2lf\t\t\t' \
COMMENT:'Packet loss\\:' \
AREA:PLNone#FFFFFF:'0%':STACK \
AREA:PL20#FFFF00:'1-20%':STACK \
AREA:PL40#FFCC00:'20-40%':STACK \
AREA:PL60#FF8000:'40-60%':STACK \
AREA:PL100#FF0000:'60-100%':STACK
EOT
      %x( #{cmd} )
    end

    private

    def rrd_file(host)
      File.join(@db_dir, host + '.rrd')
    end

  end

end

