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

      valreturn = ptr.read_ulong != 0
      needed.free
      needed = nil
      ptr.free
      ptr = nil
      valreturn
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

      valreturn = rec.read_ulong
      rec.free
      rec = nil
      valreturn
    end

    # Returns the total number of records for the given event log.
    #
    def total_records
      total = FFI::MemoryPointer.new(:ulong)

      unless GetNumberOfEventLogRecords(@handle, total)
        raise SystemCallError.new('GetNumberOfEventLogRecords', FFI.errno)
      end

      valreturn = total.read_ulong
      total.free
      total = nil
      valreturn
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
      buf    = FFI::MemoryPointer.new(:char, BUFFER_SIZE)
      bufKeeper = buf
      read   = FFI::MemoryPointer.new(:ulong)
      needed = FFI::MemoryPointer.new(:ulong)
      array  = []
      lkey   = HKEY_LOCAL_MACHINE
      hkey   = nil

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
          buf.free
          bufKeeper = nil
          buf = nil
          buf = FFI::MemoryPointer.new(:char, needed.read_ulong)
          bufKeeper = buf
          unless ReadEventLog(@handle, flags, offset, buf, buf.size, read, needed)
            raise SystemCallError.new('ReadEventLog', FFI.errno)
          end
        end

        dwread = read.read_ulong

        while dwread > 0
          record = EVENTLOGRECORD.new(buf)

          variableData = buf.read_bytes(buf.size)[EVENTLOG_FIXEDDATALENGTH..-1]

          struct = EventLogStruct.new
          struct.source         = variableData[/^[^\0]*/]
          struct.computer       = variableData[struct.source.length + 1..-1][/^[^\0]*/]
          struct.record_number  = record[:RecordNumber]
          struct.time_generated = Time.at(record[:TimeGenerated])
          struct.time_written   = Time.at(record[:TimeWritten])
          struct.event_id       = record[:EventID] & 0x0000FFFF
          struct.event_type     = get_event_type(record[:EventType])
          struct.user           = get_user(record)
          struct.category       = record[:EventCategory]
          struct.string_inserts, struct.description = get_description(variableData, record, struct.source, lkey)
          struct.data           = record[:DataLength] <= 0 ? nil : (variableData[record[:DataOffset] - EVENTLOG_FIXEDDATALENGTH, record[:DataLength]])
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

        buf = bufKeeper
        buf.clear
      end

      unless hkey.nil?
        RegCloseKey(hkey)
        hkey.free
        hkey = nil
      end
      needed.free
      needed = nil
      read.free
      read = nil
      bufKeeper = nil
      buf.free
      buf = nil
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

      unless data.nil?
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
      buf    = FFI::MemoryPointer.new(:char, BUFFER_SIZE)
      read   = FFI::MemoryPointer.new(:ulong)
      needed = FFI::MemoryPointer.new(:ulong)
      lkey   = HKEY_LOCAL_MACHINE
      hkey   = nil

      flags = EVENTLOG_BACKWARDS_READ | EVENTLOG_SEQUENTIAL_READ

      unless ReadEventLog(@handle, flags, 0, buf, buf.size, read, needed)
        if FFI.errno == ERROR_INSUFFICIENT_BUFFER
          buf.free
          buf = nil
          buf = FFI::MemoryPointer.new(:char, needed.read_ulong)
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

      variableData = buf.read_bytes(buf.size)[EVENTLOG_FIXEDDATALENGTH..-1]

      struct = EventLogStruct.new
      struct.source         = variableData[/^[^\0]*/]
      struct.computer       = variableData[struct.source.length + 1..-1][/^[^\0]*/]
      struct.record_number  = record[:RecordNumber]
      struct.time_generated = Time.at(record[:TimeGenerated])
      struct.time_written   = Time.at(record[:TimeWritten])
      struct.event_id       = record[:EventID] & 0x0000FFFF
      struct.event_type     = get_event_type(record[:EventType])
      struct.user           = get_user(record)
      struct.category       = record[:EventCategory]
      struct.string_inserts, struct.description = get_description(variableData, record, struct.source, lkey)
      struct.data           = record[:DataLength] <= 0 ? nil : (variableData[record[:DataOffset] - EVENTLOG_FIXEDDATALENGTH, record[:DataLength]])

      struct.freeze # This is read-only information

      unless hkey.nil?
        RegCloseKey(hkey)
        hkey.free
        hkey = nil
      end
      needed.free
      needed = nil
      read.free
      read = nil
      buf.free
      buf = nil

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
      namereturn = val ? name.read_string : nil

      domain_size.free
      domain_size = nil
      name_size.free
      name_size = nil

      snu.free
      snu = nil
      domain.free
      domain = nil
      name.free
      name = nil

      namereturn
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
    def get_description(variableData, record, event_source, lkey)
      str     = record[:DataLength] > 0 ? variableData[record[:StringOffset] - EVENTLOG_FIXEDDATALENGTH .. record[:DataOffset] - EVENTLOG_FIXEDDATALENGTH - 1] : variableData[record[:StringOffset] - EVENTLOG_FIXEDDATALENGTH .. -5]
      num     = record[:NumStrings]
      key     = BASE_KEY + "#{@source}\\#{event_source}"
      buf     = FFI::MemoryPointer.new(:char, 8192)
      va_list = va_list0 = (num == 0) ? [] : str.unpack('Z*' * num)

      begin
        old_wow_val = FFI::MemoryPointer.new(:int)
        Wow64DisableWow64FsRedirection(old_wow_val)

        param_exe = nil
        message_exe = nil

        regkey = Win32::Registry.open(lkey, key) rescue nil
        unless regkey.nil?
          guid = regkey["providerGuid"] rescue nil
          unless guid.nil?
            key2  = PUBBASE_KEY + "#{guid}"
            Win32::Registry.open(lkey, key2) do 
              param_exe = regkey2["ParameterMessageFile", REG_EXPAND_SZ]
              message_exe = regkey2["MessageFileName", REG_EXPAND_SZ]
            end
          else
            param_exe = regkey["ParameterMessageFile", REG_EXPAND_SZ]
            message_exe = regkey["EventMessageFile", REG_EXPAND_SZ]
          end
          regkey.close
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

              param_file = buf2.read_string[16..-1]
              param_exe = param_file.nil? ? nil : Win32::Registry.expand_environ(param_file)

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


              message_file = buf2.read_string[16..-1]
              message_exe = message_file.nil? ? nil : Win32::Registry.expand_environ(message_file)

              val.free
              val = nil
              buf2.free
              buf2 = nil
            end
          ensure
            EvtClose(pubMetadata) if pubMetadata
          end
        end

        unless param_exe.nil?
          buf.clear
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
                    buf.clear
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
                      event_id = 0xB0000000 | x.first.to_i
                      buf.clear
                      res = FormatMessage(
                        FORMAT_MESSAGE_FROM_HMODULE | FORMAT_MESSAGE_IGNORE_INSERTS,
                        hmodule,
                        event_id,
                        0,
                        buf,
                        buf.size,
                        nil
                      )
                    else
                      next
                    end
                    break if buf.read_string.gsub(/\n+/, '') != ""
                  end
                ensure
                  FreeLibrary(hmodule) if hmodule && hmodule != 0
                end
              }

              va = va.gsub("%%#{x.first}", buf.read_string.gsub(/\n+/, ''))
            }

            va
          }
        end

        unless message_exe.nil?
          buf.clear

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
                buf.clear
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
                  buf.clear
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
                #puts "message_exe#" + record[:RecordNumber].to_s + "buf:" + buf.read_string
                break if buf.read_string != "" # All messages read
              end
            ensure
              FreeLibrary(hmodule) if hmodule && hmodule != 0
            end
          }

          # Determine higest %n insert number
          # Remove %% to fix: The %1 '%2' preference item in the '%3' Group Policy Object did not apply because it failed with error code '%4'%%100790273
          max_insert = [num, buf.read_string.gsub(/%%/, '').scan(/%(\d+)/).map{ |x| x[0].to_i }.max].compact.max
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
                buf.clear
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
                #puts "message_exe2#" + record[:RecordNumber].to_s + "res1:" + res.to_s

                if res == 0
                  event_id = 0xB0000000 | event_id
                  buf.clear
                  res = FormatMessage(
                    FORMAT_MESSAGE_FROM_HMODULE | FORMAT_MESSAGE_ARGUMENT_ARRAY,
                    hmodule,
                    event_id,
                    0,
                    buf,
                    buf.size,
                    va_list_ptr
                  )
                  #puts "message_exe2#" + record[:RecordNumber].to_s + "res2:" + res.to_s
                end
                #puts "message_exe2#" + record[:RecordNumber].to_s + "buf:" + buf.read_string(60)
                break if buf.read_string != "" # All messages read
              end
            ensure
              FreeLibrary(hmodule) if hmodule && hmodule != 0
            end
          }
          if num != 0
            strptrs.each_with_index{ |p, i|
              unless p.nil?
                p.free
              end
            }
            va_list_ptr.free
            va_list_ptr = nil
          end
        end
      ensure
        Wow64RevertWow64FsRedirection(old_wow_val.read_ulong)
        old_wow_val.free
        old_wow_val = nil
      end

      resultstr = buf.read_string
      buf.free
      buf = nil
      [va_list0, resultstr]
    end
  end
end
