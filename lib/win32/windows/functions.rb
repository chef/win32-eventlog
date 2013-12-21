require 'ffi'

module Windows
  module Functions
    extend FFI::Library
    ffi_lib :advapi32

    typedef :handle, :uintptr_t
    typedef :dword, :ulong

    attach_function :BackupEventLog, :BackupEventLogW[:handle, :buffer_in], :boolean
    attach_function :ClearEventLog, :ClearEventLogW, [:handle, :buffer_in], :boolean
    attach_function :CloseEventLog, [:handle], :boolean
    attach_function :GetOldestEventLogRecord, [:handle, :pointer], :boolean
    attach_function :GetEventLogInformation, [:handle, :pointer], :boolean
    attach_function :GetNumberOfEventLogRecords, [:handle, :pointer], :boolean
    attach_function :OpenEventLog, :OpenEventLogW, [:buffer_in, :buffer_in], :handle
    attach_function :OpenBackupEventLog, :OpenBackupEventLogW, [:buffer_in, :buffer_in], :handle
    attach_function :NotifyChangeEventLog, [:handle, :handle], :boolean
    attach_function :ReadEventLog, [:handle, :dword, :dword, :buffer_out, :dword, :pointer, :pointer], :boolean
    attach_function :RegCloseKey, [:ulong], :long
    attach_function :RegCreateKeyEx, [:ulong, :string, :dword, :string, :dword, :dword, :pointer, :pointer, :pointer], :long

    ffi_lib :kernel32

    attach_function :WaitForSingleObject, [:handle, :dword], :dword
    attach_function :CreateEvent, :CreateEventA, [:pointer, :bool, :bool, :string], :handle
  end
end
