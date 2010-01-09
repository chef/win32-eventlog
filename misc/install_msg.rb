##############################################################################
# install_msg.rb
#
# This script will create a 'RubyMsg' event source in your registry.  All of
# the relevant files will be copied to the 'rubymsg' directory under C:\ruby,
# or wherever your toplevel Ruby installation directory is located.  By
# default, this will be installed in the 'Application' log.  If you wish to
# change that, change the word 'Application' to either 'Security' or 'System'
# (or your own custom log).
#
# DO NOT MOVE THE DLL FILE ONCE IT IS INSTALLED.  If you do, you will have
# to delete the registry entry and reinstall the event source pointing to the
# proper directory.
#
# You should only run this script *after* you have installed win32-eventlog.
##############################################################################
require "rbconfig"
require "fileutils"
require "win32/eventlog"
require "win32/mc"
include Win32
include Config

prefix  = CONFIG["prefix"]
msgdir  = prefix + '/rubymsg'
msgfile = 'rubymsg.mc'

Dir.mkdir(msgdir) unless File.exists?(msgdir)
FileUtils.cp("lib/rubymsg.mc",msgdir)
Dir.chdir(msgdir)

m = MC.new(msgfile)
m.create_all

puts ".dll created"

dll_file = File.expand_path(m.dll_file)

# Change 'Application' to whatever you feel is appropriate
EventLog.add_event_source(
   'source'                => "Application",
   'key_name'              => "RubyMsg",
   'category_count'        => 3,
   'event_message_file'    => dll_file,
   'category_message_file' => dll_file
)

puts "Event source 'RubyMsg' added to registry"
