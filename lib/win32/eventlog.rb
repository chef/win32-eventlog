require_relative 'windows/constants'
require_relative 'windows/structs'
require_relative 'windows/functions'

require 'win32/registry'

# The Win32 module serves as a namespace only.
module Win32

  # The EventLog class encapsulates an Event Log source and provides methods
  # for interacting with that source.
  class EventLog
    include Windows::Constants
    include Windows::Structs
    include Windows::Functions
    extend Windows::Functions

    # The EventLog::Error is raised in cases where interaction with the
    # event log should happen to fail for any reason.
    class Error < StandardError; end

    # The version of the win32-eventlog library
    VERSION = '0.6.5'

    # The log is read in chronological order, i.e. oldest to newest.
    FORWARDS_READ = EVENTLOG_FORWARDS_READ

    # The log is read in reverse chronological order, i.e. newest to oldest.
    BACKWARDS_READ = EVENTLOG_BACKWARDS_READ

    # Begin reading from a specific record.
    SEEK_READ = EVENTLOG_SEEK_READ

    # Read the records sequentially. If this is the first read operation, the
    # EVENTLOG_FORWARDS_READ or EVENTLOG_BACKWARDS_READ flags determines
    # which record is read first.
    SEQUENTIAL_READ = EVENTLOG_SEQUENTIAL_READ

    # Event types

    # Information event, an event that describes the successful operation
    # of an application, driver or service.
    SUCCESS = EVENTLOG_SUCCESS

    # Error event, an event that indicates a significant problem such as
    # loss of data or functionality.
    ERROR_TYPE = EVENTLOG_ERROR_TYPE

    # Warning event, an event that is not necessarily significant but may
    # indicate a possible future problem.
    WARN_TYPE = EVENTLOG_WARNING_TYPE

    # Information event, an event that describes the successful operation
    # of an application, driver or service.
    INFO_TYPE = EVENTLOG_INFORMATION_TYPE

    # Success audit event, an event that records an audited security attempt
    # that is successful.
    AUDIT_SUCCESS = EVENTLOG_AUDIT_SUCCESS

    # Failure audit event, an event that records an audited security attempt
    # that fails.
    AUDIT_FAILURE = EVENTLOG_AUDIT_FAILURE

    # The EventLogStruct encapsulates a single event log record.
    EventLogStruct = Struct.new('EventLogStruct', :record_number,
      :time_generated, :time_written, :event_id, :event_type, :category,
      :source, :computer, :user, :string_inserts, :description, :data
    )

    # The EventLogStruct encapsulates a single event log record.
    RegistryHKEYStruct = Struct.new('RegistryHKEYStruct', :hkey,
      :parent, :keyname, :disposition
    )

    # The name of the event log source.  This will typically be
    # 'Application', 'System' or 'Security', but could also refer to
    # a custom event log source.
    #
    attr_reader :source

    # The name of the server which the event log is reading from.
    #
    attr_reader :server

    # The name of the file used in the EventLog.open_backup method.  This is
    # set to nil if the file was not opened using the EventLog.open_backup
    # method.
    #
    attr_reader :file

    # Opens a handle to the new EventLog +source+ on +server+, or the local
    # machine if no host is specified.  Typically, your source will be
    # 'Application, 'Security' or 'System', although you can specify a
    # custom log file as well.
    #
    # If a custom, registered log file name cannot be found, the event
    # logging service opens the 'Application' log file.  This is the
    # behavior of the underlying Windows function, not my own doing.
    #
    def initialize(source = 'Application', server = nil, file = nil)
      @source = source || 'Application' # In case of explicit nil
      @server = server
      @file   = file

      # Avoid potential segfaults from win32-api
      raise TypeError unless @source.is_a?(String)
      raise TypeError unless @server.is_a?(String) if @server

      if file.nil?
        function = 'OpenEventLog'
        @handle = OpenEventLog(@server, @source)
      else
        function = 'OpenBackupEventLog'
        @handle = OpenBackupEventLog(@server, @file)
      end

      if @handle == 0
        raise SystemCallError.new(function, FFI.errno)
      end

      @totalrec = FFI::MemoryPointer.new(:ulong)
      @oldestrec = FFI::MemoryPointer.new(:ulong)
      @eventfullptr = FFI::MemoryPointer.new(:ulong, 1)
      @eventfullneeded = FFI::MemoryPointer.new(:ulong)

      @readBuf = FFI::MemoryPointer.new(:char, BUFFER_SIZE)
      @readPos = @readBuf
      @readSize = FFI::MemoryPointer.new(:ulong)
      @readNeeded = FFI::MemoryPointer.new(:ulong)
      @readHKey = FFI::MemoryPointer.new(:uintptr_t)

      @readlBuf = FFI::MemoryPointer.new(:char, BUFFER_SIZE)
      @readlSize = FFI::MemoryPointer.new(:ulong)
      @readlNeeded = FFI::MemoryPointer.new(:ulong)
      @readlHKey = FFI::MemoryPointer.new(:uintptr_t)

      @guserName = FFI::MemoryPointer.new(:char, MAX_SIZE)
      @guserName_size   = FFI::MemoryPointer.new(:ulong)
      @guserDomain = FFI::MemoryPointer.new(:char, MAX_SIZE)
      @guserDomain_size = FFI::MemoryPointer.new(:ulong)
      @guserSnu    = FFI::MemoryPointer.new(:int)

      #Max buf size 64KB required by FormatMessage https://msdn.microsoft.com/en-us/library/windows/desktop/ms679351(v=vs.85).aspx
      @gdescriptionBuf1 = FFI::MemoryPointer.new(:char, 65535)
      @gdescriptionBuf2 = FFI::MemoryPointer.new(:char, 65535)
      @gdescriptionOldWowVal = FFI::MemoryPointer.new(:int)
      @gdescriptionRetVal = FFI::MemoryPointer.new(:ulong)

      # Ensure the handle is closed at the end of a block and all pointers are free
      if block_given?
        begin
          yield self
        ensure
          close
        end
      end
    end

    # Class method aliases
    class << self
      alias :open :new
    end

    # Nearly identical to EventLog.open, except that the source is a backup
    # file and not an event source (and there is no default).
    #
    def self.open_backup(file, source = 'Application', server = nil, &block)
      @file   = file
      @source = source
      @server = server

      # Avoid potential segfaults from win32-api
      raise TypeError unless @file.is_a?(String)
      raise TypeError unless @source.is_a?(String)
      raise TypeError unless @server.is_a?(String) if @server

      self.new(source, server, file, &block)
    end

    # Adds an event source to the registry. Returns the disposition, which
    # is either REG_CREATED_NEW_KEY (1) or REG_OPENED_EXISTING_KEY (2).
    #
    # The following are valid keys:
    #
    # * source                 # Source name.  Set to "Application" by default
    # * key_name               # Name stored as the registry key
    # * category_count         # Number of supported (custom) categories
    # * event_message_file     # File (dll) that defines events
    # * category_message_file  # File (dll) that defines categories
    # * parameter_message_file # File (dll) that contains values for variables in the event description.
    # * supported_types        # See the 'event types' constants
    #
    # Of these keys, only +key_name+ is mandatory. An ArgumentError is
    # raised if you attempt to use an invalid key. If +supported_types+
    # is not specified then the following value is used:
    #
    # EventLog::ERROR_TYPE | EventLog::WARN_TYPE | EventLog::INFO_TYPE
    #
    # The +event_message_file+ and +category_message_file+ are typically,
    # though not necessarily, the same file. See the documentation on .mc files
    # for more details.
    #
    # You will need administrative privileges to use this method.
    #
    def self.add_event_source(args)
      raise TypeError unless args.is_a?(Hash)

      valid_keys = %w[
        source
        key_name
        category_count
        event_message_file
        category_message_file
        parameter_message_file
        supported_types
      ]

      # Default values
      hash = {
        'source'          => 'Application',
        'supported_types' => ERROR_TYPE | WARN_TYPE | INFO_TYPE
      }

      # Validate the keys, and convert symbols and case to lowercase strings.
      args.each{ |key, val|
        key = key.to_s.downcase
        unless valid_keys.include?(key)
          raise ArgumentError, "invalid key '#{key}'"
        end
        hash[key] = val
      }

      # The key_name must be specified
      unless hash['key_name']
        raise ArgumentError, 'no event_type specified'
      end

      key = BASE_KEY + hash['source']
      Win32::Registry::HKEY_LOCAL_MACHINE.create(key, Win32::Registry::KEY_ALL_ACCESS, Win32::Registry::REG_OPTION_NON_VOLATILE) do |regkey|
        data = "%SystemRoot%\\System32\\config\\#{hash['source']}.evt"
        regkey.write('File', Win32::Registry::REG_EXPAND_SZ, data)
      end

      valreturn = nil

      key  = BASE_KEY << hash['source'] << "\\" << hash['key_name']
      Win32::Registry::HKEY_LOCAL_MACHINE.create(key, Win32::Registry::KEY_ALL_ACCESS, Win32::Registry::REG_OPTION_NON_VOLATILE) do |regkey|
        if hash['category_count']
          regkey.write('CategoryCount', Win32::Registry::REG_DWORD, hash['category_count'])
        end

        if hash['category_message_file']
          data = File.expand_path(hash['category_message_file'])
          regkey.write('CategoryMessageFile', Win32::Registry::REG_EXPAND_SZ, data)
        end

        if hash['event_message_file']
          data = File.expand_path(hash['event_message_file'])
          regkey.write('EventMessageFile', Win32::Registry::REG_EXPAND_SZ, data)
        end

        if hash['parameter_message_file']
          data = File.expand_path(hash['parameter_message_file'])
          regkey.write('ParameterMessageFile', Win32::Registry::REG_EXPAND_SZ, data)
        end

        regkey.write('TypesSupported', Win32::Registry::REG_DWORD, hash['supported_types'])
        valreturn = regkey.disposition
      end

      valreturn
    end

    # Backs up the event log to +file+.  Note that you cannot backup to
    # a file that already exists or a Error will be raised.
    #
    def backup(file)
      raise TypeError unless file.is_a?(String)
      unless BackupEventLog(@handle, file)
        raise SystemCallError.new('BackupEventLog', FFI.errno)
      end
    end

    # Clears the EventLog.  If +backup_file+ is provided, it backs up the
    # event log to that file first.
    #
    def clear(backup_file = nil)
      raise TypeError unless backup_file.is_a?(String) if backup_file

      unless ClearEventLog(@handle, backup_file)
        raise SystemCallError.new('ClearEventLog', FFI.errno)
      end
    end

    # Closes the EventLog handle. The handle is automatically closed for you
    # if you use the block form of EventLog.new.
    #
    def close
      @gdescriptionBuf1.free
      @gdescriptionBuf1 = nil
      @gdescriptionBuf2.free
      @gdescriptionBuf2 = nil
      @gdescriptionOldWowVal.free
      @gdescriptionOldWowVal = nil
      @gdescriptionRetVal.free
      @gdescriptionRetVal = nil

      @guserSnu.free
      @guserSnu = nil
      @guserDomain_size.free
      @guserDomain_size = nil
      @guserDomain.free
      @guserDomain = nil
      @guserName_size.free
      @guserName_size = nil
      @guserName.free
      @guserName = nil

      @readlHKey.free
      @readlHKey = nil
      @readlNeeded.free
      @readlNeeded = nil
      @readlSize.free
      @readlSize = nil
      @readlBuf.free
      @readlBuf = nil

      @readHKey.free
      @readHKey = nil
      @readNeeded.free
      @readNeeded = nil
      @readSize.free
      @readSize = nil
      @readBuf.free
      @readPos = nil
      @readBuf = nil

      @eventfullneeded.free
      @eventfullneeded = nil
      @eventfullptr.free
      @eventfullptr = nil
      @oldestrec.free
      @oldestrec = nil
      @totalrec.free
      @totalrec = nil
      CloseEventLog(@handle)
    end

    # Indicates whether or not the event log is full.
    #
    def full?
      unless GetEventLogInformation(@handle, 0, @eventfullptr, @eventfullptr.size, @eventfullneeded)
        raise SystemCallError.new('GetEventLogInformation', FFI.errno)
      end

      @eventfullptr.read_ulong != 0
    end

    # Returns the absolute record number of the oldest record.  Note that
    # this is not guaranteed to be 1 because event log records can be
    # overwritten.
    #
    def oldest_record_number
      unless GetOldestEventLogRecord(@handle, @oldestrec)
        raise SystemCallError.new('GetOldestEventLogRecord', FFI.errno)
      end

      @oldestrec.read_ulong
    end

    # Returns the total number of records for the given event log.
    #
    def total_records
      unless GetNumberOfEventLogRecords(@handle, @totalrec)
        raise SystemCallError.new('GetNumberOfEventLogRecords', FFI.errno)
      end

      @totalrec.read_ulong
    end

    # Yields an EventLogStruct every time a record is written to the event
    # log. Unlike EventLog#tail, this method breaks out of the block after
    # the event.
    #
    # Raises an Error if no block is provided.
    #
    def notify_change(&block)
      unless block_given?
        raise ArgumentError, 'block missing for notify_change'
      end

      # Reopen the handle because the NotifyChangeEventLog() function will
      # choke after five or six reads otherwise.
      @handle = OpenEventLog(@server, @source)

      if @handle == 0
        raise SystemCallError.new('OpenEventLog', FFI.errno)
      end

      event = CreateEvent(nil, 0, 0, nil)

      unless NotifyChangeEventLog(@handle, event)
        raise SystemCallError.new('NotifyChangeEventLog', FFI.errno)
      end

      wait_result = WaitForSingleObject(event, INFINITE)

      begin
        if wait_result == WAIT_FAILED
          raise SystemCallError.new('WaitForSingleObject', FFI.errno)
        else
          last = read_last_event
          block.call(last)
        end
      ensure
        CloseHandle(event)
      end

      self
    end

    # Yields an EventLogStruct every time a record is written to the event
    # log, once every +frequency+ seconds. Unlike EventLog#notify_change,
    # this method does not break out of the block after the event.  The read
    # +frequency+ is set to 5 seconds by default.
    #
    # Raises an Error if no block is provided.
    #
    # The delay between reads is due to the nature of the Windows event log.
    # It is not really designed to be tailed in the manner of a Unix syslog,
    # for example, in that not nearly as many events are typically recorded.
    # It's just not designed to be polled that heavily.
    #
    def tail(frequency = 5)
      unless block_given?
        raise ArgumentError, 'block missing for tail'
      end

      old_total = total_records()
      flags     = FORWARDS_READ | SEEK_READ
      rec_num   = read_last_event.record_number

      while true
        new_total = total_records()
        if new_total != old_total
          rec_num = oldest_record_number() if full?
          read(flags, rec_num).each{ |log| yield log }
          old_total = new_total
          rec_num   = read_last_event.record_number + 1
        end
        sleep frequency
      end
    end

    # Iterates over each record in the event log, yielding a EventLogStruct
    # for each record.  The offset value is only used when used in
    # conjunction with the EventLog::SEEK_READ flag.  Otherwise, it is
    # ignored.  If no flags are specified, then the default flags are:
    #
    # EventLog::SEQUENTIAL_READ | EventLog::FORWARDS_READ
    #
    # Note that, if you're performing a SEEK_READ, then the offset must
    # refer to a record number that actually exists.  The default of 0
    # may or may not work for your particular event log.
    #
    # The EventLogStruct struct contains the following members:
    #
    # * record_number  # Fixnum
    # * time_generated # Time
    # * time_written   # Time
    # * event_id       # Fixnum
    # * event_type     # String
    # * category       # String
    # * source         # String
    # * computer       # String
    # * user           # String or nil
    # * description    # String or nil
    # * string_inserts # An array of Strings or nil
    # * data           # binary data or nil
    #
    # If no block is given the method returns an array of EventLogStruct's.
    #
    def read(flags = nil, offset = 0)
      @readBuf.clear
      @readSize.clear
      @readNeeded.clear
      array     = []
      reglkey   = Win32::Registry::HKEY_LOCAL_MACHINE
      @readHKey.clear

      unless flags
        flags = FORWARDS_READ | SEQUENTIAL_READ
      end

      unless @server.nil?
        if RegConnectRegistry(@server, Win32::Registry::HKEY_LOCAL_MACHINE.hkey, @readHKey) != 0
          raise SystemCallError.new('RegConnectRegistry', FFI.errno)
        end
        # Dirty hack to access remote registry using Win32::Registry
        reglkey = RegistryHKEYStruct.new
        reglkey.hkey = @readHKey.read_pointer.to_i
        reglkey.parent = nil
        reglkey.keyname = "REMOTE_HKEY_LOCAL_MACHINE"
        reglkey.disposition = Win32::Registry::REG_OPENED_EXISTING_KEY
      end

      while ReadEventLog(@handle, flags, offset, @readBuf, @readBuf.size, @readSize, @readNeeded) ||
        FFI.errno == ERROR_INSUFFICIENT_BUFFER

        if FFI.errno == ERROR_INSUFFICIENT_BUFFER
          @readBuf.free
          @readBuf = nil
          @readBuf = FFI::MemoryPointer.new(:char, @readNeeded.read_ulong)
          unless ReadEventLog(@handle, flags, offset, @readBuf, @readBuf.size, @readSize, @readNeeded)
            raise SystemCallError.new('ReadEventLog', FFI.errno)
          end
        end

        @readPos = @readBuf
        dwread = @readSize.read_ulong

        while dwread > 0
          recordItem = EVENTLOGRECORD.new(@readPos)

          struct = EventLogStruct.new
          struct.source         = @readPos.get_string(EVENTLOG_FIXEDDATALENGTH)
          struct.computer       = @readPos.get_string(EVENTLOG_FIXEDDATALENGTH + struct.source.length + 1)
          struct.record_number  = recordItem[:RecordNumber]
          struct.time_generated = Time.at(recordItem[:TimeGenerated])
          struct.time_written   = Time.at(recordItem[:TimeWritten])
          struct.event_id       = recordItem[:EventID] & 0x0000FFFF
          struct.event_type     = get_event_type(recordItem[:EventType])
          struct.user           = get_user(recordItem)
          struct.category       = recordItem[:EventCategory]
          struct.string_inserts, struct.description = get_description(@readPos, recordItem, struct.source, reglkey)
          struct.data           = recordItem[:DataLength] <= 0 ? nil : @readPos.get_bytes(recordItem[:DataOffset], recordItem[:DataLength])
          struct.freeze # This is read-only information

          if block_given?
            yield struct
          else
            array.push(struct)
          end

          if flags & BACKWARDS_READ > 0
            offset = recordItem[:RecordNumber] - 1
          else
            offset = recordItem[:RecordNumber] + 1
          end

          length = recordItem[:Length]

          dwread -= length
          @readPos += length
        end
      end

      if @readHKey.read_float.to_i != 0
        RegCloseKey(@readHKey.read_pointer.to_i)
      end
      block_given? ? nil : array
    end

    # This class method is nearly identical to the EventLog#read instance
    # method, except that it takes a +source+ and +server+ as the first two
    # arguments.
    #
    def self.read(source='Application', server=nil, flags=nil, offset=0)
      self.new(source, server){ |log|
        if block_given?
          log.read(flags, offset){ |els| yield els }
        else
          return log.read(flags, offset)
        end
      }
    end

    # Writes an event to the event log. The following are valid keys:
    #
    # * source     # Event log source name. Defaults to "Application".
    # * event_id   # Event ID (defined in event message file).
    # * category   # Event category (defined in category message file).
    # * data       # String, or array of strings, that is written to the log.
    # * event_type # Type of event, e.g. EventLog::ERROR_TYPE, etc.
    #
    # The +event_type+ keyword is the only mandatory keyword. The others are
    # optional. Although the +source+ defaults to "Application", I
    # recommend that you create an application specific event source and use
    # that instead. See the 'EventLog.add_event_source' method for more
    # details.
    #
    # The +event_id+ and +category+ values are defined in the message
    # file(s) that you created for your application. See the tutorial.txt
    # file for more details on how to create a message file.
    #
    # An ArgumentError is raised if you attempt to use an invalid key.
    #
    def report_event(args)
      raise TypeError unless args.is_a?(Hash)

      valid_keys  = %w[source event_id category data event_type]
      num_strings = 0

      # Default values
      hash = {
        'source'   => @source,
        'event_id' => 0,
        'category' => 0,
        'data'     => 0
      }

      # Validate the keys, and convert symbols and case to lowercase strings.
      args.each{ |key, val|
        key = key.to_s.downcase
        unless valid_keys.include?(key)
          raise ArgumentError, "invalid key '#{key}'"
        end
        hash[key] = val
      }

      # The event_type must be specified
      unless hash['event_type']
        raise ArgumentError, 'no event_type specified'
      end

      handle = RegisterEventSource(@server, hash['source'])

      if handle == 0
        raise SystemCallError.new('RegisterEventSource', FFI.errno)
      end

      data = FFI::MemoryPointer::NULL
      if hash['data'].is_a?(String)
        strptrs = []
        strptrs << FFI::MemoryPointer.from_string(hash['data'])
        strptrs << nil

        data = FFI::MemoryPointer.new(FFI::Platform::ADDRESS_SIZE/8, strptrs.size)

        strptrs.each_with_index do |p, i|
          data[i].put_pointer(0, p)
        end

        num_strings = 1
      elsif hash['data'].is_a?(Array)
        strptrs = []

        hash['data'].each{ |str|
          strptrs << FFI::MemoryPointer.from_string(str)
        }

        strptrs << nil
        data = FFI::MemoryPointer.new(FFI::Platform::ADDRESS_SIZE/8, strptrs.size)

        strptrs.each_with_index do |p, i|
          data[i].put_pointer(0, p)
        end

        num_strings = hash['data'].size
      else
        data = nil
        num_strings = 0
      end

      bool = ReportEvent(
        handle,
        hash['event_type'],
        hash['category'],
        hash['event_id'],
        nil,
        num_strings,
        0,
        data,
        nil
      )

      strptrs.each{ |p|
        unless p.nil?
          p.free
          p = nil
        end
      }
      unless data.null?
        data.free
        data = nil
      end
      
      unless bool
        raise SystemCallError.new('ReportEvent', FFI.errno)
      end
    end

    alias :write :report_event

    # Reads the last event record.
    #
    def read_last_event
      @readlBuf.clear
      @readlSize.clear
      @readlNeeded.clear
      reglkey   = Win32::Registry::HKEY_LOCAL_MACHINE
      @readlHKey.clear

      flags = BACKWARDS_READ | SEQUENTIAL_READ

      unless @server.nil?
        if RegConnectRegistry(@server, Win32::Registry::HKEY_LOCAL_MACHINE.hkey, @readlHKey) != 0
          raise SystemCallError.new('RegConnectRegistry', FFI.errno)
        end
        # Dirty hack to access remote registry using Win32::Registry
        reglkey = RegistryHKEYStruct.new
        reglkey.hkey = @readlHKey.read_pointer.to_i
        reglkey.parent = nil
        reglkey.keyname = "REMOTE_HKEY_LOCAL_MACHINE"
        reglkey.disposition = Win32::Registry::REG_OPENED_EXISTING_KEY
      end

      unless ReadEventLog(@handle, flags, 0, @readlBuf, @readlBuf.size, @readlSize, @readlNeeded)
        if FFI.errno == ERROR_INSUFFICIENT_BUFFER
          @readlBuf.free
          @readlBuf = nil
          @readlBuf = FFI::MemoryPointer.new(:char, @readlNeeded.read_ulong)
          unless ReadEventLog(@handle, flags, 0, @readlBuf, @readlBuf.size, @readlSize, @readlNeeded)
            raise SystemCallError.new('ReadEventLog', FFI.errno)
          end
        else
          raise SystemCallError.new('ReadEventLog', FFI.errno)
        end
      end


      recordItem = EVENTLOGRECORD.new(@readlBuf)

      struct = EventLogStruct.new
      struct.source         = @readlBuf.get_string(EVENTLOG_FIXEDDATALENGTH)
      struct.computer       = @readlBuf.get_string(EVENTLOG_FIXEDDATALENGTH + struct.source.length + 1)
      struct.record_number  = recordItem[:RecordNumber]
      struct.time_generated = Time.at(recordItem[:TimeGenerated])
      struct.time_written   = Time.at(recordItem[:TimeWritten])
      struct.event_id       = recordItem[:EventID] & 0x0000FFFF
      struct.event_type     = get_event_type(recordItem[:EventType])
      struct.user           = get_user(recordItem)
      struct.category       = recordItem[:EventCategory]
      struct.string_inserts, struct.description = get_description(@readlBuf, recordItem, struct.source, reglkey)
      struct.data           = recordItem[:DataLength] <= 0 ? nil : @readlBuf.get_bytes(recordItem[:DataOffset], recordItem[:DataLength])
      struct.freeze # This is read-only information

      if @readlHKey.read_float.to_i != 0
        RegCloseKey(@readlHKey.read_pointer.to_i)
      end
      struct
    end

    private

    # Private method that retrieves the user name based on data in the
    # EVENTLOGRECORD buffer.
    #
    def get_user(rec)
      return nil if rec[:UserSidLength] <= 0

      @guserName.clear
      @guserName_size.clear
      @guserDomain.clear
      @guserDomain_size.clear
      @guserSnu.clear

      @guserName_size.write_ulong(@guserName.size)
      @guserDomain_size.write_ulong(@guserDomain.size)

      offset = rec[:UserSidOffset]

      val = LookupAccountSid(
        @server,
        rec.pointer + offset,
        @guserName,
        @guserName_size,
        @guserDomain,
        @guserDomain_size,
        @guserSnu
      )

      # Return nil if the lookup failed
      val ? @guserDomain.read_string + "\\" + @guserName.read_string : nil
    end

    # Private method that converts a numeric event type into a human
    # readable string.
    #
    def get_event_type(event)
      case event
        when ERROR_TYPE
          'error'
        when WARN_TYPE
          'warning'
        when INFO_TYPE, SUCCESS
          'information'
        when AUDIT_SUCCESS
          'audit_success'
        when AUDIT_FAILURE
          'audit_failure'
        else
          nil
      end
    end

    # Private method that gets the string inserts (Array) and the full
    # event description (String) based on data from the EVENTLOGRECORD
    # buffer.
    #
    def get_description(readerBufPtr, record, event_source, reglkey)
      num     = record[:NumStrings]
      key     = BASE_KEY + "#{@source}\\#{event_source}"
      @gdescriptionBuf1.clear
      va_list = va_list0 = (num == 0) ? [] : (record[:DataLength] > 0 ? readerBufPtr.get_bytes(record[:StringOffset], record[:DataOffset] - 1) : readerBufPtr.get_bytes(record[:StringOffset], readerBufPtr.size - record[:StringOffset])).unpack('Z*' * num)

      begin
        @gdescriptionOldWowVal.clear
        Wow64DisableWow64FsRedirection(@gdescriptionOldWowVal)

        param_exe = nil
        message_exe = nil

        regkey = Win32::Registry.open(reglkey, key) rescue nil
        if !regkey.nil? && regkey.open?
          guid = regkey["providerGuid"] rescue nil
          unless guid.nil?
            key2  = PUBBASE_KEY + "#{guid}"
            Win32::Registry.open(reglkey, key2) do |regkey2|
              param_exe = regkey2["ParameterMessageFile", REG_EXPAND_SZ] rescue nil
              message_exe = regkey2["MessageFileName", REG_EXPAND_SZ] rescue nil
            end
          else
            param_exe = regkey["ParameterMessageFile", REG_EXPAND_SZ] rescue nil
            message_exe = regkey["EventMessageFile", REG_EXPAND_SZ] rescue nil
          end
          regkey.close
        else
          wevent_source = (event_source + 0.chr).encode('UTF-16LE')

          begin
            pubMetadata = EvtOpenPublisherMetadata(0, wevent_source, nil, 1024, 0)

            if pubMetadata > 0
              @gdescriptionBuf2.clear
              @gdescriptionRetVal.clear

              bool = EvtGetPublisherMetadataProperty(
                pubMetadata,
                2, # EvtPublisherMetadataParameterFilePath
                0,
                @gdescriptionBuf2.size,
                @gdescriptionBuf2,
                @gdescriptionRetVal
              )

              unless bool
                raise SystemCallError.new('EvtGetPublisherMetadataProperty', FFI.errno)
              end

              param_file = @gdescriptionBuf2.read_string[16..-1]
              param_exe = param_file.nil? ? nil : Win32::Registry.expand_environ(param_file)

              @gdescriptionBuf2.clear
              @gdescriptionRetVal.clear

              bool = EvtGetPublisherMetadataProperty(
                pubMetadata,
                3, # EvtPublisherMetadataMessageFilePath
                0,
                @gdescriptionBuf2.size,
                @gdescriptionBuf2,
                @gdescriptionRetVal
              )

              unless bool
                raise SystemCallError.new('EvtGetPublisherMetadataProperty', FFI.errno)
              end


              message_file = @gdescriptionBuf2.read_string[16..-1]
              message_exe = message_file.nil? ? nil : Win32::Registry.expand_environ(message_file)
            end
          ensure
            EvtClose(pubMetadata) if pubMetadata
          end
        end

        unless param_exe.nil?
          @gdescriptionBuf1.clear
          va_list = va_list0.map{ |v|
            va = v

            v.scan(/%%(\d+)/).uniq.each{ |x|
              param_exe.split(';').each{ |lfile|
                if lfile.to_s.strip.length == 0
                  next
                end
                #To fix "string contains null byte" on some registry entry (corrupted?)
                lfile.gsub!(/\0/, '')
                begin
                  hmodule  = LoadLibraryEx(
                    lfile,
                    0,
                    DONT_RESOLVE_DLL_REFERENCES | LOAD_LIBRARY_AS_DATAFILE
                  )

                  if hmodule != 0
                    @gdescriptionBuf1.clear
                    res = FormatMessage(
                      FORMAT_MESSAGE_FROM_HMODULE | FORMAT_MESSAGE_ARGUMENT_ARRAY,
                      hmodule,
                      x.first.to_i,
                      0,
                      @gdescriptionBuf1,
                      @gdescriptionBuf1.size,
                      v
                    )

                    if res == 0
                      event_id = 0xB0000000 | x.first.to_i
                      @gdescriptionBuf1.clear
                      res = FormatMessage(
                        FORMAT_MESSAGE_FROM_HMODULE | FORMAT_MESSAGE_IGNORE_INSERTS,
                        hmodule,
                        event_id,
                        0,
                        @gdescriptionBuf1,
                        @gdescriptionBuf1.size,
                        nil
                      )
                    else
                      next
                    end
                    break if @gdescriptionBuf1.read_string.gsub(/\n+/, '') != ""
                  end
                ensure
                  FreeLibrary(hmodule) if hmodule && hmodule != 0
                end
              }

              va = va.gsub("%%#{x.first}", @gdescriptionBuf1.read_string.gsub(/\n+/, ''))
            }

            va
          }
        end

        unless message_exe.nil?
          @gdescriptionBuf1.clear

          # Try to retrieve message *without* expanding the inserts yet
          message_exe.split(';').each{ |lfile|
            if lfile.to_s.strip.length == 0
              next
            end
            #To fix "string contains null byte" on some registry entry (corrupted?)
            lfile.gsub!(/\0/, '')
            #puts "message_exe#" + record[:RecordNumber].to_s + "lfile:" + lfile
            begin
              hmodule = LoadLibraryEx(
                lfile,
                0,
                DONT_RESOLVE_DLL_REFERENCES | LOAD_LIBRARY_AS_DATAFILE
              )

              event_id = record[:EventID]

              if hmodule != 0
                @gdescriptionBuf1.clear
                res = FormatMessage(
                  FORMAT_MESSAGE_FROM_HMODULE | FORMAT_MESSAGE_IGNORE_INSERTS,
                  hmodule,
                  event_id,
                  0,
                  @gdescriptionBuf1,
                  @gdescriptionBuf1.size,
                  nil
                )

                if res == 0
                  event_id = 0xB0000000 | event_id
                  @gdescriptionBuf1.clear
                  res = FormatMessage(
                    FORMAT_MESSAGE_FROM_HMODULE | FORMAT_MESSAGE_IGNORE_INSERTS,
                    hmodule,
                    event_id,
                    0,
                    @gdescriptionBuf1,
                    @gdescriptionBuf1.size,
                    nil
                  )
                end
                #puts "message_exe#" + record[:RecordNumber].to_s + "@gdescriptionBuf1:" + @gdescriptionBuf1.read_string
                break if @gdescriptionBuf1.read_string != "" # All messages read
              end
            ensure
              FreeLibrary(hmodule) if hmodule && hmodule != 0
            end
          }

          # Determine higest %n insert number
          # Remove %% to fix: The %1 '%2' preference item in the '%3' Group Policy Object did not apply because it failed with error code '%4'%%100790273
          max_insert = [num, @gdescriptionBuf1.read_string.gsub(/%%/, '').scan(/%(\d+)/).map{ |x| x[0].to_i }.max].compact.max
          #puts "message_exe#" + record[:RecordNumber].to_s + "max_insert:" + max_insert.to_s

          # Insert dummy strings not provided by caller
          ((num+1)..(max_insert)).each{ |x| va_list.push("%#{x}") }

          strptrs = []
          if num == 0
            va_list_ptr = nil
          else
            va_list.each{ |x| strptrs << FFI::MemoryPointer.from_string(x) }
            strptrs << nil

            va_list_ptr = FFI::MemoryPointer.new(FFI::Platform::ADDRESS_SIZE/8, strptrs.size)

            strptrs.each_with_index{ |p, i|
              va_list_ptr[i].put_pointer(0, p)
              #unless p.nil?
              #  puts "message_exe2#" + record[:RecordNumber].to_s + "va_list_ptr:" + i.to_s + "/" + p.read_string
              #end
            }
          end

          message_exe.split(';').each{ |lfile|
            if lfile.to_s.strip.length == 0
              next
            end
            #To fix "string contains null byte" on some registry entry (corrupted?)
            lfile.gsub!(/\0/, '')
            #puts "message_exe2#" + record[:RecordNumber].to_s + "lfile:" + lfile
            begin
             hmodule = LoadLibraryEx(
                lfile,
                0,
                DONT_RESOLVE_DLL_REFERENCES | LOAD_LIBRARY_AS_DATAFILE
              )

              event_id = record[:EventID]

              if hmodule != 0
                @gdescriptionBuf1.clear
                res = FormatMessage(
                  FORMAT_MESSAGE_FROM_HMODULE |
                  FORMAT_MESSAGE_ARGUMENT_ARRAY,
                  hmodule,
                  event_id,
                  0,
                  @gdescriptionBuf1,
                  @gdescriptionBuf1.size,
                  va_list_ptr
                )
                #puts "message_exe2#" + record[:RecordNumber].to_s + "res1:" + res.to_s

                if res == 0
                  event_id = 0xB0000000 | event_id
                  @gdescriptionBuf1.clear
                  res = FormatMessage(
                    FORMAT_MESSAGE_FROM_HMODULE | FORMAT_MESSAGE_ARGUMENT_ARRAY,
                    hmodule,
                    event_id,
                    0,
                    @gdescriptionBuf1,
                    @gdescriptionBuf1.size,
                    va_list_ptr
                  )
                  #puts "message_exe2#" + record[:RecordNumber].to_s + "res2:" + res.to_s
                end
                #puts "message_exe2#" + record[:RecordNumber].to_s + "@gdescriptionBuf1:" + @gdescriptionBuf1.read_string(60)
                break if @gdescriptionBuf1.read_string != "" # All messages read
              end
            ensure
              FreeLibrary(hmodule) if hmodule && hmodule != 0
            end
          }
          if num != 0
            strptrs.each{ |p|
              unless p.nil?
                p.free
                p = nil
              end
            }
            va_list_ptr.free
            va_list_ptr = nil
          end
        end
      ensure
        Wow64RevertWow64FsRedirection(@gdescriptionOldWowVal.read_ulong)
      end

      resultstr = @gdescriptionBuf1.read_string.force_encoding("Windows-1252")
      va_list0.map! { |x| x.force_encoding("Windows-1252") }
      [va_list0, resultstr]
    end
  end
end
