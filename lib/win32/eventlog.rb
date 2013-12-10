require 'socket'
require 'win32ole'

# The Win32 module serves only as a namespace
module Win32
  # The EventLog class encapsulates the Microsoft Windows Event Log
  class EventLog
    # Error typically raised if any of the EventLog methods fail
    class Error < StandardError; end

    # The version of the win32-eventlog library
    VERSION = '0.6.0'

    # The name of the event log source. This will typically be
    # 'Application', 'System' or 'Security', but could also refer to
    # a custom event log source.
    #
    attr_reader :source

    # The name of the server which the event log is reading from.
    #
    attr_reader :server

    # The name of the file used in the EventLog.open_backup method. This is
    # set to nil if the file was not opened using the EventLog.open_backup
    # method.
    #
    attr_reader :file

    EventLogStruct = Struct.new(
      'EventLog',
      :Category,
      :CategoryString,
      :ComputerName,
      :Data,
      :EventCode,
      :EventIdentifier,
      :EventType,
      :InsertionStrings,
      :Logfile,
      :Message,
      :RecordNumber,
      :SourceName,
      :TimeGenerated,
      :TimeWritten,
      :Type,
      :User
    )

    # Opens a handle to the new EventLog +source+ on +server+, or the local
    # machine if no host is specified. Typically, your source will be
    # 'Application, 'Security' or 'System', although you can specify a
    # custom log file as well.
    #
    # If a custom, registered log file name cannot be found, the event
    # logging service opens the 'Application' log file. This is the
    # behavior of the underlying Windows function, not my own doing.
    #
    # Example:
    #
    # log = Win32::EventLog.new
    #
    def initialize(source = 'Application', server = nil, file = nil)
      server ||= Socket.gethostname

      @source = source
      @server = server
      @file   = file

      raise TypeError unless @source.is_a?(String)
      raise TypeError unless @server.is_a?(String) if @server
      raise TypeError unless @file.is_a?(String) if @file

      connect_string = "winmgmts:{impersonationLevel=impersonate,(Security)}"
      connect_string << "//#{server}/root/cimv2"

      begin
        @wmi = WIN32OLE.connect(connect_string)
      rescue WIN32OLERuntimeError => err
        raise Error, err
      end

      if block_given?
        begin
          yield self
        ensure
          close
        end
      end
    end

    def close
      @wmi.ole_free
    end

    class << self
      alias :open :new
    end

    def backup(file)
      raise TypeError unless file.is_a?(String)

      sql = %Q{
        select * from Win32_NTEventLogFile where LogFileName = '#{@source}'
      }.strip

      begin
        @wmi.ExecQuery(sql).each{ |logfile|
          val = logfile.BackupEventLog(file)

          if val != 0
            msg = SystemCallError.new('BackupEventLog', val).message
            raise Error, msg
          end
        }
      rescue WIN32OLERuntimeError => err
        raise Error, err
      end
    end

    def read(conditions = nil)
      array = block_given? ? nil : []

      sql = %Q{
        select * from Win32_NTLogEvent
        where Logfile = '#{@source}'
      }

      if conditions
        conditions.each{ |key, value|
          if value.is_a?(String)
            sql << " and #{key} = '#{value}'"
          else
            sql << " and #{key} = #{value}"
          end
        }
      end

      @wmi.ExecQuery(sql).each{ |log|
        struct = EventLogStruct.new(
          log.Category,
          log.CategoryString,
          log.ComputerName,
          log.Data,
          log.EventCode,
          log.EventIdentifier,
          log.EventType,
          log.InsertionStrings,
          log.Logfile,
          log.Message,
          log.RecordNumber,
          log.SourceName,
          log.TimeGenerated,
          log.TimeWritten,
          log.Type,
          log.User
        )

        if block_given?
          yield struct.freeze
        else
          array << struct.freeze
        end
      }

      array
    end
  end
end

if $0 == __FILE__
  include Win32
  log = EventLog.new
  #log.backup("C:\\Users\\djberge\\test.evt")
  #log.backup("test.evt")
end
