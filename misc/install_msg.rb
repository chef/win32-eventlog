###############################################################################
# install_msg.rb
#
# This script will create a 'RubyMsg' event source in your registry. All of
# the relevant files will be copied to the 'rubymsg' directory under C:\ruby,
# or wherever your toplevel Ruby installation directory is located. By default
# this will be installed in the 'Application' log. If you wish to change that
# then change the word 'Application' to either 'Security' or 'System' (or your
# own custom log).
#
# DO NOT MOVE THE DLL FILE ONCE IT IS INSTALLED. If you do, you will have
# to delete the registry entry and reinstall the event source pointing to the
# proper directory.
#
# You should only run this script *after* you have installed win32-eventlog.
###############################################################################
require 'rbconfig'
require 'fileutils'
require 'win32/eventlog'
require 'win32/mc'
include Win32

msg_dir  = File.join(RbConfig::CONFIG['prefix'], 'rubymsg')
msg_file = 'rubymsg.mc'

Dir.mkdir(msg_dir) unless File.exists?(msg_dir)
FileUtils.cp('misc/rubymsg.mc', msg_dir)
Dir.chdir(msg_dir)

mc = Win32::MC.new(msg_file)
mc.create_all

puts ".dll created"

dll_file = File.expand_path(mc.dll_file)

# Change 'Application' to whatever you feel is appropriate
Win32::EventLog.add_event_source(
  :source                => "Application",
  :key_name              => "RubyMsg",
  :category_count        => 3,
  :event_message_file    => dll_file,
  :category_message_file => dll_file
)

puts "Event source 'RubyMsg' added to registry"
