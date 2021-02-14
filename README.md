# PingMon - A latency and packet loss monitor

PingMon is a daemon that gets started from systemd to monitor the
latency and packet loss from the current host to a number of
pre-defined other hosts. These hosts are organized in groups to keep
the overview. Latency and packet loss are measured by the 'ping'
system command. The daemon features a built-in web server that allows
the current and historic data to be inspected. 

## Installation

PingMon is designed to run on modern Linux systems that feature 'ping'
and 'rrdtools' and 'systemd'. There are pretty standard on all Linux
distribution. Make sure you have the relevant package installed and in
your $PATH environment variable.

To start off, create a directory .pingmon in your home directory.

```
mkdir -p ${HOME}/.pingmon
```

In this directory, create a file that looks like the following. The file
must be named config.json. You can use the following content as a
template and adapt it to your needs. By default, hosts are pinged
every 15 seconds. Optionally, you can use an intervall of 300 seconds
(5 minutes) which is recommended for all remote hosts. Other intervals
are not supported.

```json
{
  "hostname" : "your.host",
  "port" : 3333,
  "host_groups" : [
    {
      "name" : "Networking Gear",
      "hosts" : [
        {
          "name" : "firewall"
        },
        {
          "name" : "accesspoint"
        },
        {
          "name" : "switch"
        }
      ]
    },
    {
      "name" : "Remote Servers",
      "hosts" : [
        {
          "name" : "my.web.server.com"
          "ping_inverval_secs" : 300
        },
        {
          "name" : "my.mail.server.com"
          "ping_inverval_secs" : 300
        },
        {
          "name" : "my.vm.server.com"
          "ping_inverval_secs" : 300
        }
      ]
    }
  ]
}
```

Next, you need to create the following directory.

```
mkdir -p ${HOME}/.config/systemd/user
```

In this directory, create a file called pingmon.service. You can use
the following template, but you must adapt it to your configuration.
The network-online.target is only needed if you mount your home
directory via NFS. Replace <your_login> and the path to pingmon with
your local settings.

```
[Unit]
Description=Ping latency monitoring service
After=network-online.target home-<your_login>.mount
Requires=home-<your_login>.mount

[Service]
Type=simple
ExecStart=/path/to/bin/pingmon

[Install]
WantedBy=default.target
```

## Usage

Now you can start the daemon via systemd.

```
systemctl --user enable pingmon
systemctl --user start pingmon
```

Use the following command to check if pingmon is running properly.

```
systemctl --user status pingmon
```

If all is going well, you should not be seing any error messages and
every few calls to systemctl status should show the forked-off ping
processes.

Now you can point your web browser to http://localhost:3333/pingmon to
view your latency and packet loss statistics.

## Copyright and License

Copyright (c) 2021 by Chris Schlaeger <chris@taskjuggler.org>

PEROBS and all accompanying files are licensed under GNU GPL v2
License. See COPYING file for details.

## Contributing

1. Fork it ( https://github.com/scrapper/perobs/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
