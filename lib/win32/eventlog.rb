require 'socket'
require 'win32ole'

module Win32
  class EventLog
    class Error < StandardError; end

    attr_reader :source, :server, :file

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

    def initialize(source = 'Application', server = nil, file = nil)
      server ||= Socket.gethostname

      @source = source
      @server = server
      @file   = file

      connect_string = "winmgmts:{impersonationLevel=impersonate}"
      connect_string << "//#{server}/root/cimv2"

      begin
        @wmi = WIN32OLE.connect(connect_string)
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
