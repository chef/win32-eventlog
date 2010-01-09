############################################################################
# example_notify.rb (win32-eventlog)
#
# A sample script for demonstrating the tail method.  Start this in its own
# terminal.  Then, in another terminal, write an entry to the event log
# (or force an entry via some other means) and watch the output.
#
# You can run this code via the 'example_notify' rake task.
############################################################################
Thread.new { loop { sleep 0.01 } } # Allow Ctrl-C

require 'win32/eventlog'
include Win32

log = EventLog.open

# replace 'tail' with 'notify_change' to see the difference
log.tail{ |struct|
   puts "Got something"
   p struct
   puts
}

log.close