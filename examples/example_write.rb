##############################################################################
# example_write.rb
#
# Tests both the creation of an Event Log source and writing to the Event
# Log. You can run this via the 'rake example_write' task.
#
# Modify as you see fit.
##############################################################################

# Prompt user to continue, or not...
msg = <<TEXT

	This script will create an event source 'foo' in your registry and
	write an event to the 'Application' source.
	Is that ok [y/N]?
TEXT
print msg

ans = STDIN.gets.chomp
unless ans == "y" || ans == "Y"
	puts "Ok, exiting..."
   	exit!
end

require "win32/eventlog"
require "win32/mc"
include Win32

puts "EventLog VERSION: " + EventLog::VERSION
puts "MC VERSION: " + MC::VERSION
sleep 1

m = MC.new("foo.mc")
m.create_all
puts ".dll created"
sleep 1

dll_file = File.expand_path(m.dll_file)

EventLog.add_event_source(
   'source'                => "Application",
   'key_name'              => "foo",
   'category_count'        => 2,
   'event_message_file'    => dll_file,
   'category_message_file' => dll_file
)

puts "Event source added to registry"
sleep 1

e1 = EventLog.open("Application")

e1.report_event(
   :source      => "foo",
   :event_type  => EventLog::WARN,
   :category    => "0x00000002L".hex,
   :event_id    => "0xC0000003L".hex,
   :data        => "Danger Will Robinson!"
)

puts "Event written to event log"

e1.close

puts "Finished.  Exiting..."