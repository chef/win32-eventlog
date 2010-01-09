############################################################################
# example_read.rb (win32-eventlog)
#
# Test script for general futzing.  This will attempt to read and backup
# your Event Log. You can run this example via the 'rake example_read'
# task.
#
# Modify as you see fit.
############################################################################
require 'win32/eventlog'
include Win32

puts "VERSION: " + EventLog::VERSION
sleep 1

# A few different ways to read an event log

el = EventLog.new("Application")
el.read{ |log|
   p log
}
el.close

EventLog.read("Application"){ |log|
   p log
   puts
}

EventLog.open("Application") do |log|
   log.read{ |struct|
      p struct
      puts
   }
end

backup_file = "C:\\event_backup1"
File.delete(backup_file) if File.exists?(backup_file)

e1 = EventLog.open("System")
puts "System log opened"

e2 = EventLog.open("Application")
puts "Application log opened"

e3 = EventLog.open("Security")
puts "Security log opened"

puts "=" * 40

puts "Total system records: " + e1.total_records.to_s
puts "Total application records: " + e2.total_records.to_s
puts "Total security records: " + e3.total_records.to_s

puts "=" * 40

puts "Oldest system record number: " + e1.oldest_record_number.to_s
puts "Oldest application record number: " + e2.oldest_record_number.to_s
puts "Oldest security record number: " + e3.oldest_record_number.to_s

puts "=" * 40

e2.backup(backup_file)
puts "Application log backed up to #{backup_file}"

puts "=" * 40

e1.close
puts "System log closed"

e2.close
puts "Application log closed"

e3.close
puts "Security log closed"

e4 = EventLog.open_backup(backup_file)
e4.read{ |elr|
   p elr
   puts
}
puts "Finished reading backup file"
e4.close

File.delete(backup_file)