# Free space on the filesystem that holds uploads.
#
# The server runs on Ubuntu, where statvfs answers without spawning a process.
# Development on Windows skips the guard: the quotas still apply, so a dev
# machine cannot fill a production disk by accident.
{% if flag?(:linux) %}
  private lib LibStatvfs
    struct Statvfs
      f_bsize : UInt64
      f_frsize : UInt64
      f_blocks : UInt64
      f_bfree : UInt64
      f_bavail : UInt64
      f_files : UInt64
      f_ffree : UInt64
      f_favail : UInt64
      f_fsid : UInt64
      f_flag : UInt64
      f_namemax : UInt64
      f_spare : Int32[6]
    end

    fun statvfs(path : UInt8*, buffer : Statvfs*) : Int32
  end
{% end %}

module DiskSpace
  def self.available_bytes(path : String = ".") : Int64?
    {% if flag?(:linux) %}
      buffer = uninitialized LibStatvfs::Statvfs
      status = LibStatvfs.statvfs(File.expand_path(path), pointerof(buffer))
      return nil unless status == 0

      (buffer.f_bavail.to_i64 * buffer.f_frsize.to_i64)
    {% else %}
      nil
    {% end %}
  end
end
