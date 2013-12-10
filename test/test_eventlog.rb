##############################################################################
# test_eventlog.rb
#
# Test case for the win32-eventlog package. You should run this test case
# via the 'rake test' Rakefile task. This test will take a minute or two
# to complete.
#############################################################################
require 'win32/eventlog'
require 'win32/security'
require 'sys/admin'
require 'socket'
require 'test-unit'
require 'fileutils'

class TC_Win32_EventLog < Test::Unit::TestCase
  def self.startup
    @@host = Socket.gethostname
    @@elevated = Win32::Security.elevated_security?
  end

  def setup
    @log      = Win32::EventLog.new('Application')
    @logfile  = 'temp.evt'
    @login    = Sys::Admin.get_login
    @user     = Sys::Admin.get_user(@login, :localaccount => true)
    @bakfile  = File.join(@user.dir, 'test_event_log.bak')
    @records  = []
    @last     = nil
  end

  test "version number is set to the expected value" do
    assert_equal('0.6.0', Win32::EventLog::VERSION)
  end

  test "constructor with no arguments uses expected defaults" do
    assert_nothing_raised{ @log = Win32::EventLog.new }
    assert_equal(@@host, @log.server)
    assert_equal('Application', @log.source)
    assert_nil(@log.file)
  end

  test "constructor with source argument works as expected" do
    assert_nothing_raised{ @log = Win32::EventLog.new('Security') }
    assert_equal(@@host, @log.server)
    assert_equal('Security', @log.source)
    assert_nil(@log.file)
  end

  test "constructor with hostname works as expected" do
    assert_nothing_raised{ @log = Win32::EventLog.new('Security', @@host) }
    assert_equal(@@host, @log.server)
    assert_equal('Security', @log.source)
    assert_nil(@log.file)
  end

  test "constructor accepts a block" do
    assert_nothing_raised{ Win32::EventLog.new{ } }
    Win32::EventLog.new{ |log| assert_kind_of(Win32::EventLog, log) }
  end

  test "open is an alias for new" do
    assert_respond_to(Win32::EventLog, :open)
    #assert_alias_method(Win32::EventLog, :open, :new)
  end

  test "the source, host and file arguments must be a string" do
    assert_raises(TypeError){ Win32::EventLog.open(1) }
    assert_raises(TypeError){ Win32::EventLog.open('Application', 1) }
    assert_raises(TypeError){ Win32::EventLog.open('Application', @@host, 1) }
  end

  test "open_backup basic functionality" do
    assert_respond_to(Win32::EventLog, :open_backup)
  end

  test "open_backup works as expected" do
    Win32::EventLog.new('Application').backup(@bakfile)
    assert_nothing_raised{ @log = Win32::EventLog.open_backup(@bakfile) }
    assert_kind_of(Win32::EventLog, @log)
    assert_nothing_raised{ @log.read{ break } }
  end

  test "the source, server and file arguments for open_backup must be a string" do
    assert_raises(TypeError){ Win32::EventLog.open(1) }
    assert_raises(TypeError){ Win32::EventLog.open('Application', 1) }
    assert_raises(TypeError){ Win32::EventLog.open('Application', @@host, 1) }
  end

=begin
   # Ensure that an Array is returned in non-block form and that none of the
   # descriptions are nil.
   #
   # The test for descriptions was added as a result of ruby-talk:116528.
   # Thanks go to Joey Gibson for the spot.  The test for unique record
   # numbers was added to ensure no dups.
   #
   def test_class_read_verification
      assert_nothing_raised{ @array = EventLog.read }
      assert_kind_of(Array, @array)

      record_numbers = []
      @array.each{ |log|
         assert_not_nil(log.description)
         assert_equal(false, record_numbers.include?(log.record_number))
         record_numbers << log.record_number
      }
   end

   # I've added explicit breaks because an event log could be rather large.
   #
   def test_class_read_basic
      assert_nothing_raised{ EventLog.read{ break } }
      assert_nothing_raised{ EventLog.read("Application"){ break } }
      assert_nothing_raised{ EventLog.read("Application", nil){ break } }
      assert_nothing_raised{ EventLog.read("Application", nil, nil){ break } }
      assert_nothing_raised{ EventLog.read("Application", nil, nil, 10){ break } }
   end

   def test_class_read_expected_errors
      assert_raises(ArgumentError){
         EventLog.read("Application", nil, nil, nil, nil){}
      }
   end
=end

  test "read method works as expected" do
    assert_respond_to(@log, :read)
    assert_nothing_raised{ @log.read{ break } }
  end

=begin
   def test_read_expected_errors
      flags = EventLog::FORWARDS_READ | EventLog::SEQUENTIAL_READ
      assert_raises(ArgumentError){ @log.read(flags, 500, 'foo') }
   end

   def test_seek_read
      flags = EventLog::SEEK_READ | EventLog::FORWARDS_READ
      assert_nothing_raised{ @last = @log.read[-10].record_number }
      assert_nothing_raised{
         @records = EventLog.read(nil, nil, flags, @last)
      }
      assert_equal(10, @records.length)
   end

   # This test could fail, since a record number + 10 may not actually exist.
   def test_seek_read_backwards
      flags = EventLog::SEEK_READ | EventLog::BACKWARDS_READ
      assert_nothing_raised{ @last = @log.oldest_record_number + 10 }
      assert_nothing_raised{ @records = EventLog.read(nil, nil, flags, @last) }
      assert_equal(11, @records.length)
   end

   def test_eventlog_struct_is_frozen
      EventLog.read{ |log| @entry = log; break }
      assert_true(@entry.frozen?)
   end

   def test_server
      assert_respond_to(@log, :server)
      assert_raises(NoMethodError){ @log.server = 'foo' }
   end

   def test_source
      assert_respond_to(@log, :source)
      assert_kind_of(String, @log.source)
      assert_raises(NoMethodError){ @log.source = 'foo' }
   end

   def test_file
      assert_respond_to(@log, :file)
      assert_nil(@log.file)
      assert_raises(NoMethodError){ @log.file = 'foo' }
   end
=end

  test "backup method basic functionality" do
    assert_respond_to(@log, :backup)
  end

  test "backup method works as expected" do
    assert_nothing_raised{ @log.backup(@bakfile) }
    assert(File.exists?(@bakfile))
  end

  test "backup method fails is file already exists" do
    FileUtils.touch(@bakfile)
    assert_raises(Win32::EventLog::Error){ @log.backup(@bakfile) }
  end

  test "backup method requires a single argument" do
    assert_raise(ArgumentError){ @log.backup }
    assert_raise(ArgumentError){ @log.backup(@bakfile, @bakfile) }
  end

  test "backup method requires a string" do
    assert_raise(TypeError){ @log.backup(1) }
  end

=begin
   # Since I don't want to actually clear anyone's event log, I can't really
   # verify that it works.
   #
   def test_clear
      assert_respond_to(@log, :clear)
   end

   def test_full
      assert_respond_to(@log, :full?)
      assert_nothing_raised{ @log.full? }
   end

   def test_close
      assert_respond_to(@log, :close)
      assert_nothing_raised{ @log.close }
   end

   def test_oldest_record_number
      assert_respond_to(@log, :oldest_record_number)
      assert_kind_of(Fixnum, @log.oldest_record_number)
   end

   def test_total_records
      assert_respond_to(@log, :total_records)
      assert_kind_of(Fixnum, @log.total_records)
   end

   # We can't test that this method actually executes properly since it goes
   # into an endless loop.
   #
   def test_tail
      assert_respond_to(@log, :tail)
      assert_raises(EventLog::Error){ @log.tail } # requires block
   end

   # We can't test that this method actually executes properly since it goes
   # into an endless loop.
   #
   def test_notify_change
      assert_respond_to(@log, :notify_change)
      assert_raises(EventLog::Error){ @log.notify_change } # requires block
   end

   # I can't really do more in depth testing for this method since there
   # isn't an event source I can reliably and safely write to.
   #
   def test_report_event
      assert_respond_to(@log, :report_event)
      assert_respond_to(@log, :write) # alias
      assert_raises(ArgumentError){ @log.report_event }
   end

   def test_read_event_constants
      assert_not_nil(EventLog::FORWARDS_READ)
      assert_not_nil(EventLog::BACKWARDS_READ)
      assert_not_nil(EventLog::SEEK_READ)
      assert_not_nil(EventLog::SEQUENTIAL_READ)
   end

   def test_event_type_constants
      assert_not_nil(EventLog::SUCCESS)
      assert_not_nil(EventLog::ERROR)
      assert_not_nil(EventLog::WARN)
      assert_not_nil(EventLog::INFO)
      assert_not_nil(EventLog::AUDIT_SUCCESS)
      assert_not_nil(EventLog::AUDIT_FAILURE)
   end
=end

  def teardown
    @log.close rescue nil
    File.delete(@bakfile) if File.exists?(@bakfile)
    @logfile  = nil
    @records  = nil
    @last     = nil
  end

  def self.shutdown
    @@host = nil
    @@elevated = nil
  end
end
