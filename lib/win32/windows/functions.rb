require "ffi" unless defined?(FFI)

module Windows
  module EventLogFunctions
    extend FFI::Library
    ffi_lib :advapi32

    # https://github.com/jruby/jruby/issues/2293
    if RUBY_PLATFORM == "java" && ENV_JAVA["sun.arch.data.model"] == "64"
      typedef :ulong_long, :handle
    else
      typedef :uintptr_t, :handle
    end

    typedef :uintptr_t, :hkey
    typedef :ulong, :dword
    typedef :ushort, :word

    attach_function :BackupEventLog, :BackupEventLogA, %i{handle string}, :bool
    attach_function :ClearEventLog, :ClearEventLogA, %i{handle string}, :bool
    attach_function :CloseEventLog, [:handle], :bool
    attach_function :GetOldestEventLogRecord, %i{handle pointer}, :bool
    attach_function :GetEventLogInformation, %i{handle dword pointer dword pointer}, :bool
    attach_function :GetNumberOfEventLogRecords, %i{handle pointer}, :bool
    attach_function :LookupAccountSid, :LookupAccountSidA, %i{string pointer pointer pointer pointer pointer pointer}, :bool
    attach_function :OpenEventLog, :OpenEventLogA, %i{string string}, :handle
    attach_function :OpenBackupEventLog, :OpenBackupEventLogA, %i{string string}, :handle
    attach_function :NotifyChangeEventLog, %i{handle handle}, :bool
    attach_function :ReadEventLog, :ReadEventLogA, %i{handle dword dword buffer_out dword pointer pointer}, :bool
    attach_function :RegCloseKey, [:hkey], :long
    attach_function :RegConnectRegistry, :RegConnectRegistryA, %i{string hkey pointer}, :long
    attach_function :RegCreateKeyEx, :RegCreateKeyExA, %i{hkey string dword string dword dword pointer pointer pointer}, :long
    attach_function :RegisterEventSource, :RegisterEventSourceA, %i{string string}, :handle
    attach_function :RegOpenKeyEx, :RegOpenKeyExA, %i{hkey string dword ulong pointer}, :long
    attach_function :RegQueryValueEx, :RegQueryValueExA, %i{hkey string pointer pointer pointer pointer}, :long
    attach_function :RegSetValueEx, :RegSetValueExA, %i{hkey string dword dword pointer dword}, :long
    attach_function :ReportEvent, :ReportEventA, %i{handle word word dword pointer word dword pointer pointer}, :bool

    ffi_lib :kernel32

    attach_function :CloseHandle, [:handle], :bool
    attach_function :CreateEvent, :CreateEventA, %i{pointer int int string}, :handle
    attach_function :ExpandEnvironmentStrings, :ExpandEnvironmentStringsA, %i{string pointer dword}, :dword
    attach_function :FormatMessage, :FormatMessageA, %i{dword uintptr_t dword dword pointer dword pointer}, :dword
    attach_function :FreeLibrary, [:handle], :bool
    attach_function :LoadLibraryEx, :LoadLibraryExA, %i{string handle dword}, :handle
    attach_function :WaitForSingleObject, %i{handle dword}, :dword
    attach_function :Wow64DisableWow64FsRedirection, [:pointer], :bool
    attach_function :Wow64RevertWow64FsRedirection, [:ulong], :bool

    begin
      ffi_lib :wevtapi

      attach_function :EvtClose, [:handle], :bool
      attach_function :EvtOpenPublisherMetadata, %i{handle buffer_in buffer_in dword dword}, :handle
      attach_function :EvtGetPublisherMetadataProperty, %i{handle int dword dword pointer pointer}, :bool
    rescue LoadError
      # 2003
    end
  end
end
