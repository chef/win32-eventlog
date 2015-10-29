##############################################################################
# test_eventlog.rb
#
# Test case for the win32-eventlog package. You should run this test case
# via the 'rake test' Rakefile task. This test will take a minute or two
# to complete.
#############################################################################
require 'test-unit'
require 'win32/eventlog'
require 'socket'
require 'tmpdir'
include Win32

class TC_Win32_EventLog < Test::Unit::TestCase
  def self.startup
    @@hostname = Socket.gethostname
  end

  def setup
    @log      = EventLog.new('Application')
    @logfile  = 'temp.evt'
    @bakfile  = File.join(Dir.tmpdir, 'test_event_log.bak')
    @records  = []
    @last     = nil
  end

  test "version constant is set to expected value" do
    assert_equal('0.6.5', EventLog::VERSION)
  end

  test "constructor basic functionality" do
    assert_respond_to(EventLog, :new)
    assert_nothing_raised{ EventLog.new }
  end

  test "constructor accepts a block" do
    assert_nothing_raised{ EventLog.new{ |log| } }
  end

  test "constructor accepts a log type" do
    assert_nothing_raised{ EventLog.new('System') }
  end

  test "constructor accepts a host name" do
    assert_nothing_raised{ EventLog.new('System', @@hostname) }
  end

  #test "open is a singleton alias for new" do
  #  assert_alias_method(EventLog, :new, :open)
  #end

  test "constructor accepts a maximum of three arguments" do
    assert_raises(ArgumentError){ EventLog.new('System', @@hostname, 'foo', 'bar') }
  end

  test "arguments to constructor must be strings" do
    assert_raises(TypeError){ EventLog.open(1) }
    assert_raises(TypeError){ EventLog.open('System', 1) }
  end

  test "source accessor method basic functionality" do
    @log = EventLog.new('Application', @@hostname)
    assert_respond_to(@log, :source)
    assert_equal('Application', @log.source)
  end

  test "server accessor method basic functionality" do
    @log = EventLog.new('Application', @@hostname)
    assert_respond_to(@log, :server)
    assert_equal(@@hostname, @log.server)
  end

  test "backup basic functionality" do
    assert_respond_to(@log, :backup)
    assert_nothing_raised{ @log.backup(@bakfile) }
  end

  test "backup works as expected" do
    assert_nothing_raised{ @log.backup(@bakfile) }
    assert(File.exist?(@bakfile))
  end

  test "backup method fails if backup file already exists" do
    assert_nothing_raised{ @log.backup(@bakfile) }
    assert_raise(SystemCallError){ @log.backup(@bakfile) }
  end

  test "open_backup basic functionality" do
    assert_respond_to(EventLog, :open_backup)
  end

  test "open_backup works as expected" do
    EventLog.new('Application', @@hostname){ |log| log.backup(@bakfile) }
    assert_nothing_raised{ @log = EventLog.open_backup(@bakfile) }
    assert_kind_of(EventLog, @log)
  end

  test "it is possible to read and close the backup log file" do
    EventLog.new('Application', @@hostname){ |log| log.backup(@bakfile) }
    @log = EventLog.open_backup(@bakfile)
    assert_nothing_raised{ @log.read{ break } }
    assert_nothing_raised{ @log.close }
  end

  # Ensure that an Array is returned in non-block form and that none of the
  # descriptions are nil.
  #
  # The test for descriptions was added as a result of ruby-talk:116528.
  # Thanks go to Joey Gibson for the spot.  The test for unique record
  # numbers was added to ensure no dups.
  #
  test "singleton read method works as expected" do
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
  test "singleton read method does not require any arguments" do
    assert_nothing_raised{ EventLog.read{ break } }
  end

  test "singleton read method accepts a log type" do
    assert_nothing_raised{ EventLog.read("Application"){ break } }
  end

  test "singleton read method accepts a server argument" do
    assert_nothing_raised{ EventLog.read("Application", nil){ break } }
  end

  test "singleton read method accepts a flags argument" do
    assert_nothing_raised{ EventLog.read("Application", nil, nil){ break } }
  end

  test "singleton read method accepts an offset argument" do
    assert_nothing_raised{ EventLog.read("Application", nil, nil, 10){ break } }
  end

  test "singleton read method accepts a maximum of four arguments" do
    assert_raises(ArgumentError){
      EventLog.read("Application", nil, nil, nil, nil){}
    }
  end

  test "instance method read basic functionality" do
    assert_respond_to(@log, :read)
    assert_nothing_raised{ @log.read{ break } }
  end

  test "instance method read accepts flags" do
    flags = EventLog::FORWARDS_READ | EventLog::SEQUENTIAL_READ
    assert_nothing_raised{ @log.read(flags){ break } }
  end

  test "instance method read accepts an offset" do
    assert_nothing_raised{ @log.read(nil, 500){ break } }
  end

  test "instance method read accepts a maximum of two arguments" do
    assert_raises(ArgumentError){ @log.read(nil, 500, 'foo') }
  end

  test "read_last_event method basic functionality" do
    assert_respond_to(@log, :read_last_event)
    assert_nothing_raised{ @log.read_last_event }
  end

  test "read_last_event returns the expected results" do
    assert_kind_of(Win32::EventLog::EventLogStruct, @log.read_last_event)
  end

  test "seek_read flag plus forwards_read flag works as expected" do
    flags = EventLog::SEEK_READ | EventLog::FORWARDS_READ
    assert_nothing_raised{ @last = @log.read[-10].record_number }
    assert_nothing_raised{
      @records = EventLog.read(nil, nil, flags, @last)
    }
    assert_equal(10, @records.length)
  end

  # This test could fail, since a record number + 10 may not actually exist.
  test "seek_read flag plus backwards_read flag works as expected" do
    flags = EventLog::SEEK_READ | EventLog::BACKWARDS_READ
    assert_nothing_raised{ @last = @log.oldest_record_number + 10 }
    assert_nothing_raised{ @records = EventLog.read(nil, nil, flags, @last) }
    assert_equal(11, @records.length)
  end

  test "the eventlog struct returned by read is frozen" do
    EventLog.read{ |log| @entry = log; break }
    assert_true(@entry.frozen?)
  end

  test "server method basic functionality" do
    assert_respond_to(@log, :server)
    assert_nothing_raised{ @log.server }
    assert_nil(@log.server)
  end

  test "server method is readonly" do
    assert_raises(NoMethodError){ @log.server = 'foo' }
  end

  test "source method basic functionality" do
    assert_respond_to(@log, :source)
    assert_nothing_raised{ @log.source }
    assert_kind_of(String, @log.source)
  end

  test "source method is readonly" do
    assert_raises(NoMethodError){ @log.source = 'foo' }
  end

  test "file method basic functionality" do
    assert_respond_to(@log, :file)
    assert_nothing_raised{ @log.file }
    assert_nil(@log.file)
  end

  test "file method is readonly" do
    assert_raises(NoMethodError){ @log.file = 'foo' }
  end

  # Since I don't want to actually clear anyone's event log, I can't really
  # verify that it works.
  test "clear method basic functionality" do
    assert_respond_to(@log, :clear)
  end

  test "full method basic functionality" do
    assert_respond_to(@log, :full?)
    assert_nothing_raised{ @log.full? }
  end

  test "full method returns a boolean" do
    assert_boolean(@log.full?)
  end

  test "close method basic functionality" do
    assert_respond_to(@log, :close)
    assert_nothing_raised{ @log.close }
  end

  test "oldest_record_number basic functionality" do
    assert_respond_to(@log, :oldest_record_number)
    assert_nothing_raised{ @log.oldest_record_number }
    assert_kind_of(Fixnum, @log.oldest_record_number)
  end

  test "total_records basic functionality" do
    assert_respond_to(@log, :total_records)
    assert_nothing_raised{ @log.total_records }
    assert_kind_of(Fixnum, @log.total_records)
  end

  # We can't test that this method actually executes properly since it goes
  # into an endless loop.
  #
  test "tail basic functionality" do
    assert_respond_to(@log, :tail)
    assert_raises(ArgumentError){ @log.tail }
  end

  # We can't test that this method actually executes properly since it goes
  # into an endless loop.
  #
  test "notify_change basic functionality" do
    assert_respond_to(@log, :notify_change)
    assert_raises(ArgumentError){ @log.notify_change }
  end

  # I can't really do more in depth testing for this method since there
  # isn't an event source I can reliably and safely write to.
  #
  test "report_event basic functionality" do
    assert_respond_to(@log, :report_event)
    assert_raises(ArgumentError){ @log.report_event }
  end

  test "write is an alias for report_event" do
    assert_respond_to(@log, :write)
    assert_alias_method(@log, :write, :report_event)
  end

  test "read event constants" do
    assert_not_nil(EventLog::FORWARDS_READ)
    assert_not_nil(EventLog::BACKWARDS_READ)
    assert_not_nil(EventLog::SEEK_READ)
    assert_not_nil(EventLog::SEQUENTIAL_READ)
  end

  test "event type constants" do
    assert_not_nil(EventLog::SUCCESS)
    assert_not_nil(EventLog::ERROR_TYPE)
    assert_not_nil(EventLog::WARN_TYPE)
    assert_not_nil(EventLog::INFO_TYPE)
    assert_not_nil(EventLog::AUDIT_SUCCESS)
    assert_not_nil(EventLog::AUDIT_FAILURE)
  end

  def teardown
    @log.close rescue nil
    File.delete(@bakfile) if File.exist?(@bakfile)
    @logfile  = nil
    @records  = nil
    @last     = nil
  end

  def self.shutdown
    @@hostname = nil
  end
end
