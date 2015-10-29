require_relative 'windows/constants'
require_relative 'windows/structs'
require_relative 'windows/functions'

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
      :source, :computer, :user, :string_inserts, :description
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

      # Ensure the handle is closed at the end of a block
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

      key_base = "SYSTEM\\CurrentControlSet\\Services\\EventLog\\"

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

      hkey = FFI::MemoryPointer.new(:uintptr_t)
      disposition = FFI::MemoryPointer.new(:ulong)

      key = key_base + hash['source']

      rv = RegCreateKeyEx(
        HKEY_LOCAL_MACHINE,
        key,
        0,
        nil,
        REG_OPTION_NON_VOLATILE,
        KEY_WRITE,
        nil,
        hkey,
        disposition
      )

      if rv != ERROR_SUCCESS
        raise SystemCallError.new('RegCreateKeyEx', rv)
      end

      hkey = hkey.read_pointer.to_i
      data = "%SystemRoot%\\System32\\config\\#{hash['source']}.evt"

      begin
        rv = RegSetValueEx(
          hkey,
          'File',
          0,
          REG_EXPAND_SZ,
          data,
          data.size
        )

        if rv != ERROR_SUCCESS
          raise SystemCallError.new('RegSetValueEx', rv)
        end
      ensure
        RegCloseKey(hkey)
      end

      hkey = FFI::MemoryPointer.new(:uintptr_t)
      disposition = FFI::MemoryPointer.new(:ulong)

      key  = key_base << hash['source'] << "\\" << hash['key_name']

      begin
        rv = RegCreateKeyEx(
          HKEY_LOCAL_MACHINE,
          key,
          0,
          nil,
          REG_OPTION_NON_VOLATILE,
          KEY_WRITE,
          nil,
          hkey,
          disposition
        )

        if rv != ERROR_SUCCESS
          raise SystemCallError.new('RegCreateKeyEx', rv)
        end

        hkey = hkey.read_pointer.to_i

        if hash['category_count']
          data = FFI::MemoryPointer.new(:ulong).write_ulong(hash['category_count'])

          rv = RegSetValueEx(
            hkey,
            'CategoryCount',
            0,
            REG_DWORD,
            data,
            data.size
          )

          if rv != ERROR_SUCCESS
            raise SystemCallError.new('RegSetValueEx', rv)
          end
        end

        if hash['category_message_file']
          data = File.expand_path(hash['category_message_file'])
          data = FFI::MemoryPointer.from_string(data)

          rv = RegSetValueEx(
            hkey,
            'CategoryMessageFile',
            0,
            REG_EXPAND_SZ,
            data,
            data.size
          )

          if rv != ERROR_SUCCESS
            raise SystemCallError.new('RegSetValueEx', rv)
          end
        end

        if hash['event_message_file']
          data = File.expand_path(hash['event_message_file'])
          data = FFI::MemoryPointer.from_string(data)

          rv = RegSetValueEx(
            hkey,
            'EventMessageFile',
            0,
            REG_EXPAND_SZ,
            data,
            data.size
          )

          if rv != ERROR_SUCCESS
            raise SystemCallError.new('RegSetValueEx', rv)
          end
        end

        if hash['parameter_message_file']
          data = File.expand_path(hash['parameter_message_file'])
          data = FFI::MemoryPointer.from_string(data)

          rv = RegSetValueEx(
            hkey,
            'ParameterMessageFile',
            0,
            REG_EXPAND_SZ,
            data,
            data.size
          )

          if rv != ERROR_SUCCESS
            raise SystemCallError.new('RegSetValueEx', rv)
          end
        end

        data = FFI::MemoryPointer.new(:ulong).write_ulong(hash['supported_types'])

        rv = RegSetValueEx(
          hkey,
          'TypesSupported',
          0,
          REG_DWORD,
          data,
          data.size
        )

        if rv != ERROR_SUCCESS
          raise SystemCallError.new('RegSetValueEx', rv)
        end
      ensure
        RegCloseKey(hkey)
      end

      disposition.read_ulong
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
      CloseEventLog(@handle)
    end

    # Indicates whether or not the event log is full.
    #
    def full?
      ptr = FFI::MemoryPointer.new(:ulong, 1)
      needed = FFI::MemoryPointer.new(:ulong)

      unless GetEventLogInformation(@handle, 0, ptr, ptr.size, needed)
        raise SystemCallError.new('GetEventLogInformation', FFI.errno)
      end

      ptr.read_ulong != 0
    end

    # Returns the absolute record number of the oldest record.  Note that
    # this is not guaranteed to be 1 because event log records can be
    # overwritten.
    #
    def oldest_record_number
      rec = FFI::MemoryPointer.new(:ulong)

      unless GetOldestEventLogRecord(@handle, rec)
        raise SystemCallError.new('GetOldestEventLogRecord', FFI.errno)
      end

      rec.read_ulong
    end

    # Returns the total number of records for the given event log.
    #
    def total_records
      total = FFI::MemoryPointer.new(:ulong)

      unless GetNumberOfEventLogRecords(@handle, total)
        raise SystemCallError.new('GetNumberOfEventLogRecords', FFI.errno)
      end

      total.read_ulong
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
    #
    # If no block is given the method returns an array of EventLogStruct's.
    #
    def read(flags = nil, offset = 0)
      buf    = FFI::MemoryPointer.new(:char, BUFFER_SIZE)
      read   = FFI::MemoryPointer.new(:ulong)
      needed = FFI::MemoryPointer.new(:ulong)
      array  = []
      lkey   = HKEY_LOCAL_MACHINE

      unless flags
        flags = FORWARDS_READ | SEQUENTIAL_READ
      end

      if @server
        hkey = FFI::MemoryPointer.new(:uintptr_t)
        if RegConnectRegistry(@server, HKEY_LOCAL_MACHINE, hkey) != 0
          raise SystemCallError.new('RegConnectRegistry', FFI.errno)
        end
        lkey = hkey.read_pointer.to_i
      end

      while ReadEventLog(@handle, flags, offset, buf, buf.size, read, needed) ||
        FFI.errno == ERROR_INSUFFICIENT_BUFFER

        if FFI.errno == ERROR_INSUFFICIENT_BUFFER
          needed = needed.read_ulong / EVENTLOGRECORD.size
          buf = FFI::MemoryPointer.new(EVENTLOGRECORD, needed)
          unless ReadEventLog(@handle, flags, offset, buf, buf.size, read, needed)
            raise SystemCallError.new('ReadEventLog', FFI.errno)
          end
        end

        dwread = read.read_ulong

        while dwread > 0
          struct = EventLogStruct.new
          record = EVENTLOGRECORD.new(buf)

          struct.source         = buf.read_bytes(buf.size)[56..-1][/^[^\0]*/]
          struct.computer       = buf.read_bytes(buf.size)[56 + struct.source.length + 1..-1][/^[^\0]*/]
          struct.record_number  = record[:RecordNumber]
          struct.time_generated = Time.at(record[:TimeGenerated])
          struct.time_written   = Time.at(record[:TimeWritten])
          struct.event_id       = record[:EventID] & 0x0000FFFF
          struct.event_type     = get_event_type(record[:EventType])
          struct.user           = get_user(record)
          struct.category       = record[:EventCategory]
          struct.string_inserts, struct.description = get_description(buf, struct.source, lkey)

          struct.freeze # This is read-only information

          if block_given?
            yield struct
          else
            array.push(struct)
          end

          if flags & EVENTLOG_BACKWARDS_READ > 0
            offset = record[:RecordNumber] - 1
          else
            offset = record[:RecordNumber] + 1
          end

          length = record[:Length]

          dwread -= length
          buf += length
        end

        buf  = FFI::MemoryPointer.new(:char, BUFFER_SIZE)
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

      if hash['data'].is_a?(String)
        strptrs = []
        strptrs << FFI::MemoryPointer.from_string(hash['data'])
        strptrs << nil

        data = FFI::MemoryPointer.new(:pointer, strptrs.size)

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
        data = FFI::MemoryPointer.new(:pointer, strptrs.size)

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

      unless bool
        raise SystemCallError.new('ReportEvent', FFI.errno)
      end
    end

    alias :write :report_event

    # Reads the last event record.
    #
    def read_last_event
      buf    = FFI::MemoryPointer.new(:char, BUFFER_SIZE)
      read   = FFI::MemoryPointer.new(:ulong)
      needed = FFI::MemoryPointer.new(:ulong)
      lkey   = HKEY_LOCAL_MACHINE

      flags = EVENTLOG_BACKWARDS_READ | EVENTLOG_SEQUENTIAL_READ

      unless ReadEventLog(@handle, flags, 0, buf, buf.size, read, needed)
        if FFI.errno == ERROR_INSUFFICIENT_BUFFER
          needed = needed.read_ulong / EVENTLOGRECORD.size
          buf = FFI::MemoryPointer.new(EVENTLOGRECORD, needed)
          unless ReadEventLog(@handle, flags, 0, buf, buf.size, read, needed)
            raise SystemCallError.new('ReadEventLog', FFI.errno)
          end
        else
          raise SystemCallError.new('ReadEventLog', FFI.errno)
        end
      end

      if @server
        hkey = FFI::MemoryPointer.new(:uintptr_t)
        if RegConnectRegistry(@server, HKEY_LOCAL_MACHINE, hkey) != 0
          raise SystemCallError.new('RegConnectRegistry', FFI.errno)
        end
        lkey = hkey.read_pointer.to_i
      end

      record = EVENTLOGRECORD.new(buf)

      struct = EventLogStruct.new
      struct.source         = buf.read_bytes(buf.size)[56..-1][/^[^\0]*/]
      struct.computer       = buf.read_bytes(buf.size)[56 + struct.source.length + 1..-1][/^[^\0]*/]
      struct.record_number  = record[:RecordNumber]
      struct.time_generated = Time.at(record[:TimeGenerated])
      struct.time_written   = Time.at(record[:TimeWritten])
      struct.event_id       = record[:EventID] & 0x0000FFFF
      struct.event_type     = get_event_type(record[:EventType])
      struct.user           = get_user(record)
      struct.category       = record[:EventCategory]
      struct.string_inserts, struct.description = get_description(buf, struct.source, lkey)

      struct.freeze # This is read-only information

      struct
    end

    private

    # Private method that retrieves the user name based on data in the
    # EVENTLOGRECORD buffer.
    #
    def get_user(rec)
      return nil if rec[:UserSidLength] <= 0

      name   = FFI::MemoryPointer.new(:char, MAX_SIZE)
      domain = FFI::MemoryPointer.new(:char, MAX_SIZE)
      snu    = FFI::MemoryPointer.new(:int)

      name_size   = FFI::MemoryPointer.new(:ulong)
      domain_size = FFI::MemoryPointer.new(:ulong)

      name_size.write_ulong(name.size)
      domain_size.write_ulong(domain.size)

      offset = rec[:UserSidOffset]

      val = LookupAccountSid(
        @server,
        rec.pointer + offset,
        name,
        name_size,
        domain,
        domain_size,
        snu
      )

      # Return nil if the lookup failed
      return val ? name.read_string : nil
    end

    # Private method that converts a numeric event type into a human
    # readable string.
    #
    def get_event_type(event)
      case event
        when EVENTLOG_ERROR_TYPE
          'error'
        when EVENTLOG_WARNING_TYPE
          'warning'
        when EVENTLOG_INFORMATION_TYPE, EVENTLOG_SUCCESS
          'information'
        when EVENTLOG_AUDIT_SUCCESS
          'audit_success'
        when EVENTLOG_AUDIT_FAILURE
          'audit_failure'
        else
          nil
      end
    end

    # Private method that gets the string inserts (Array) and the full
    # event description (String) based on data from the EVENTLOGRECORD
    # buffer.
    #
    def get_description(buf, event_source, lkey)
      rec     = EVENTLOGRECORD.new(buf)
      str     = buf.read_bytes(buf.size)[rec[:StringOffset] .. -1]
      num     = rec[:NumStrings]
      hkey    = FFI::MemoryPointer.new(:uintptr_t)
      key     = BASE_KEY + "#{@source}\\#{event_source}"
      buf     = FFI::MemoryPointer.new(:char, 8192)
      va_list = va_list0 = (num == 0) ? [] : str.unpack('Z*' * num)

      begin
        old_wow_val = FFI::MemoryPointer.new(:int)
        Wow64DisableWow64FsRedirection(old_wow_val)

        param_exe = nil
        message_exe = nil

        if RegOpenKeyEx(lkey, key, 0, KEY_READ, hkey) == 0
          hkey  = hkey.read_pointer.to_i
          value = 'providerGuid'

          guid_ptr = FFI::MemoryPointer.new(:char, MAX_SIZE)
          size_ptr = FFI::MemoryPointer.new(:ulong)

          size_ptr.write_ulong(guid_ptr.size)

          if RegQueryValueEx(hkey, value, nil, nil, guid_ptr, size_ptr) == 0
            guid  = guid_ptr.read_string
            hkey2 = FFI::MemoryPointer.new(:uintptr_t)
            key   = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\WINEVT\\Publishers\\#{guid}"

            guid_ptr.free

            if RegOpenKeyEx(lkey, key, 0, KEY_READ|0x100, hkey2) == 0
              hkey2  = hkey2.read_pointer.to_i

              value = 'ParameterMessageFile'
              file_ptr = FFI::MemoryPointer.new(:char, MAX_SIZE)
              size_ptr.clear.write_ulong(file_ptr.size)

              if RegQueryValueEx(hkey2, value, nil, nil, file_ptr, size_ptr) == 0
                file = file_ptr.read_string
                exe  = FFI::MemoryPointer.new(:char, MAX_SIZE)
                ExpandEnvironmentStrings(file, exe, exe.size)
                param_exe = exe.read_string
              end

              value = 'MessageFileName'

              file_ptr.clear
              size_ptr.clear.write_ulong(file_ptr.size)

              if RegQueryValueEx(hkey2, value, nil, nil, file_ptr, size_ptr) == 0
                file = file_ptr.read_string
                exe  = FFI::MemoryPointer.new(:char, MAX_SIZE)
                ExpandEnvironmentStrings(file, exe, exe.size)
                message_exe = exe.read_string
              end

              RegCloseKey(hkey2)

              file_ptr.free
              size_ptr.free
            end
          else
            value = 'ParameterMessageFile'
            file_ptr = FFI::MemoryPointer.new(:char, MAX_SIZE)
            size_ptr.clear.write_ulong(file_ptr.size)

            if RegQueryValueEx(hkey, value, nil, nil, file_ptr, size_ptr) == 0
              file = file_ptr.read_string
              exe  = FFI::MemoryPointer.new(:char, MAX_SIZE)
              ExpandEnvironmentStrings(file, exe, exe.size)
              param_exe = exe.read_string
            end

            value = 'EventMessageFile'

            file_ptr.clear
            size_ptr.clear.write_ulong(file_ptr.size)

            if RegQueryValueEx(hkey, value, nil, nil, file_ptr, size_ptr) == 0
              file = file_ptr.read_string
              exe  = FFI::MemoryPointer.new(:char, MAX_SIZE)
              ExpandEnvironmentStrings(file, exe, exe.size)
              message_exe = exe.read_string
            end

            file_ptr.free
            size_ptr.free
          end

          RegCloseKey(hkey)
        else
          wevent_source = (event_source + 0.chr).encode('UTF-16LE')

          begin
            pubMetadata = EvtOpenPublisherMetadata(0, wevent_source, nil, 1024, 0)

            if pubMetadata > 0
              buf2 = FFI::MemoryPointer.new(:char, 8192)
              val  = FFI::MemoryPointer.new(:ulong)

              bool = EvtGetPublisherMetadataProperty(
                pubMetadata,
                2, # EvtPublisherMetadataParameterFilePath
                0,
                buf2.size,
                buf2,
                val
              )

              unless bool
                raise SystemCallError.new('EvtGetPublisherMetadataProperty', FFI.errno)
              end

              file = buf2.read_string[16..-1]
              exe  = FFI::MemoryPointer.new(:char, MAX_SIZE)
              ExpandEnvironmentStrings(file, exe, exe.size)
              param_exe = exe.read_string

              buf2.clear
              val.clear

              bool = EvtGetPublisherMetadataProperty(
                pubMetadata,
                3, # EvtPublisherMetadataMessageFilePath
                0,
                buf2.size,
                buf2,
                val
              )

              unless bool
                raise SystemCallError.new('EvtGetPublisherMetadataProperty', FFI.errno)
              end

              exe.clear

              file = buf2.read_string[16..-1]
              ExpandEnvironmentStrings(file, exe, exe.size)
              message_exe = exe.read_string

              buf2.free
              val.free
              exe.free
            end
          ensure
            EvtClose(pubMetadata) if pubMetadata
          end
        end

        if param_exe != nil
          va_list = va_list0.map{ |v|
            va = v

            v.scan(/%%(\d+)/).uniq.each{ |x|
              param_exe.split(';').each{ |lfile|
                hmodule  = LoadLibraryEx(
                  lfile,
                  0,
                  DONT_RESOLVE_DLL_REFERENCES | LOAD_LIBRARY_AS_DATAFILE
                )

                if hmodule != 0
                  res = FormatMessage(
                    FORMAT_MESSAGE_FROM_HMODULE | FORMAT_MESSAGE_ARGUMENT_ARRAY,
                    hmodule,
                    x.first.to_i,
                    0,
                    buf,
                    buf.size,
                    v
                  )

                  if res == 0
                    event_id = 0xB0000000 | event_id
                    res = FormatMessage(
                      FORMAT_MESSAGE_FROM_HMODULE | FORMAT_MESSAGE_IGNORE_INSERTS,
                      hmodule,
                      event_id,
                      0,
                      buf,
                      buf.size,
                      nil
                    )
                  end

                  FreeLibrary(hmodule)
                  break if buf.read_string != ""
                end
              }

              va = va.gsub("%%#{x.first}", buf.read_string)
            }

            va
          }
        end

        if message_exe != nil
          buf.clear

          # Try to retrieve message *without* expanding the inserts yet
          message_exe.split(';').each{ |lfile|
            hmodule = LoadLibraryEx(
              lfile,
              0,
              DONT_RESOLVE_DLL_REFERENCES | LOAD_LIBRARY_AS_DATAFILE
            )

            event_id = rec[:EventID]

            if hmodule != 0
              res = FormatMessage(
                FORMAT_MESSAGE_FROM_HMODULE | FORMAT_MESSAGE_IGNORE_INSERTS,
                hmodule,
                event_id,
                0,
                buf,
                buf.size,
                nil
              )

              if res == 0
                event_id = 0xB0000000 | event_id

                res = FormatMessage(
                  FORMAT_MESSAGE_FROM_HMODULE | FORMAT_MESSAGE_IGNORE_INSERTS,
                  hmodule,
                  event_id,
                  0,
                  buf,
                  buf.size,
                  nil
                )
              end

              FreeLibrary(hmodule)
              break if buf.read_string != "" # All messages read
            end
          }

          # Determine higest %n insert number
          max_insert = [num, buf.read_string.scan(/%(\d+)/).map{ |x| x[0].to_i }.max].compact.max

          # Insert dummy strings not provided by caller
          ((num+1)..(max_insert)).each{ |x| va_list.push("%#{x}") }

          if num == 0
            va_list_ptr = FFI::MemoryPointer.new(:pointer)
          else
            strptrs = []
            va_list.each{ |x| strptrs << FFI::MemoryPointer.from_string(x) }
            strptrs << nil

            va_list_ptr = FFI::MemoryPointer.new(:pointer, strptrs.size)

            strptrs.each_with_index{ |p, i|
              va_list_ptr[i].put_pointer(0, p)
            }
          end

          message_exe.split(';').each{ |lfile|
            hmodule = LoadLibraryEx(
              lfile,
              0,
              DONT_RESOLVE_DLL_REFERENCES | LOAD_LIBRARY_AS_DATAFILE
            )

            event_id = rec[:EventID]

            if hmodule != 0
              res = FormatMessage(
                FORMAT_MESSAGE_FROM_HMODULE |
                FORMAT_MESSAGE_ARGUMENT_ARRAY,
                hmodule,
                event_id,
                0,
                buf,
                buf.size,
                va_list_ptr
              )

              if res == 0
                event_id = 0xB0000000 | event_id

                res = FormatMessage(
                  FORMAT_MESSAGE_FROM_HMODULE | FORMAT_MESSAGE_ARGUMENT_ARRAY,
                  hmodule,
                  event_id,
                  0,
                  buf,
                  buf.size,
                  va_list_ptr
                )
              end

              FreeLibrary(hmodule)
              break if buf.read_string != "" # All messages read
            end
          }
        end
      ensure
        Wow64RevertWow64FsRedirection(old_wow_val.read_ulong)
      end

      [va_list0, buf.read_string]
    end
  end
end
