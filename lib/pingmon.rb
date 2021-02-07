require "pingmon/version"

# Some dependencies may not be installed as Ruby Gems but as local sources.
# Add them to the LOAD_PATH.
%w( perobs ).each do |lib_dir|
  $:.unshift(File.join(File.dirname(__FILE__), '..', '..', lib_dir, 'lib'))
end
$:.unshift(File.dirname(__FILE__))

require 'pingmon/PingMon'

module PingMon

  PingMonitor.new().main(ARGV)

end

