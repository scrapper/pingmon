require 'erb'

require 'pingmon/models/HostGroups'
require 'pingmon/controllers/DropdownMenu'

module PingMon

  class GraphPage

    class DurationItem < Struct.new(:name, :value)
    end

    DURATIONS = [
      DurationItem.new('6 hours', 6 * 60 * 60),
      DurationItem.new('12 hours', 12 * 60 * 60),
      DurationItem.new('1 day', 24 * 60 * 60),
      DurationItem.new('1 week', 7 * 24 * 60 * 60),
      DurationItem.new('1 month', 30 * 24 * 60 * 60)
    ]

    def initialize(host_groups)
      @host_groups = host_groups

      @group_menu = DropdownMenu.new('Host Groups', 'pingmon', 'group')
      host_groups.groups.each do |group|
        @group_menu.add_item(group.name)
      end

      @duration_menu = DropdownMenu.new('Duration', 'pingmon', 'duration')
      DURATIONS.each do |item|
        @duration_menu.add_item(item.name, item.value.to_s)
      end
    end

    def render(args)
      template_file = File.join(File.dirname(__FILE__), 'GraphPage.html.erb')
      template = File.read(template_file)

      unless (group_name = args['group'].first)
        current_group = @host_groups.groups.first
      else
        current_group = @host_groups.groups.find { |g| g.name == group_name } ||
          @host_groups.groups.first
      end

      unless (d = args['duration']) && (duration = d.first)
        current_duration = DURATIONS.first.value
      else
        current_duration = (
          DURATIONS.find { |d| d.value == duration.to_i } ||
          DURATIONS.first
        ).value
      end
      ERB.new(template).result(binding)
    end

    private

    def app_url(path, args)
      path.join('/') + '?' + URI.encode_www_form(args)
    end

  end

end

