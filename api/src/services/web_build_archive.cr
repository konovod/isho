require "compress/zip"

# Validation and unpacking of a browser build archive.
#
# The central directory is read first: it gives the total uncompressed size and
# the entry list without touching the disk, so an archive that would exceed the
# quota, contain thousands of files or escape the target directory is rejected
# before anything is written.
module WebBuildArchive
  MAX_FILES       = 5_000
  MAX_PATH_LENGTH =   240
  MAX_DEPTH       =    16

  class Error < Exception
    getter code : String

    def initialize(@code : String, message : String)
      super(message)
    end
  end

  record Info, uncompressed_bytes : Int64, files : Int32, entry : String

  def self.inspect(path : String, requested_entry : String? = nil) : Info
    entries = [] of {String, Int64}

    Compress::Zip::File.open(path) do |zip|
      zip.entries.each do |entry|
        next if entry.dir?

        name = entry.filename
        next if ignored?(name)

        validate_name!(name)
        if entries.size >= MAX_FILES
          raise Error.new("archive_too_many_files", "The archive contains too many files")
        end

        entries << {name, entry.uncompressed_size.to_i64}
      end
    end

    raise Error.new("empty_archive", "The archive has no files") if entries.empty?

    total = entries.sum { |(_, size)| size }
    entry = requested_entry ? validate_entry!(requested_entry, entries) : detect_entry(entries)
    Info.new(total, entries.size, entry)
  end

  # Writes every file into `destination`, refusing to exceed `max_bytes` in
  # total (a zip bomb can lie in its central directory).
  def self.extract(path : String, destination : String, max_bytes : Int64) : Nil
    root = File.expand_path(destination)
    written = 0_i64

    Compress::Zip::File.open(path) do |zip|
      zip.entries.each do |entry|
        next if entry.dir?

        name = entry.filename
        next if ignored?(name)

        dest = File.expand_path(File.join(root, name))
        unless dest.starts_with?(root + '/') || dest.starts_with?(root + '\\')
          raise Error.new("invalid_archive", "An archive entry points outside the build directory")
        end

        Dir.mkdir_p(File.dirname(dest))
        File.open(dest, "wb") do |output|
          entry.open do |io|
            written += copy_limited(io, output, max_bytes - written)
          end
        end
      end
    end
  end

  private def self.copy_limited(source : IO, destination : IO, remaining : Int64) : Int64
    buffer = Bytes.new(64 * 1024)
    copied = 0_i64

    while (read = source.read(buffer)) > 0
      copied += read
      if copied > remaining
        raise Error.new("archive_too_large", "The archive expands to more than it declared")
      end
      destination.write(buffer[0, read])
    end

    copied
  end

  private def self.detect_entry(entries : Array({String, Int64})) : String
    names = entries.map(&.[0])
    root = names.find { |name| name.downcase == "index.html" }
    return root if root

    candidates = names.select { |name| File.basename(name).downcase == "index.html" }
    return candidates.first if candidates.size == 1

    if candidates.empty?
      raise Error.new("index_html_missing", "The archive has no index.html")
    end

    raise Error.new("index_html_ambiguous", "The archive has several index.html files; choose one")
  end

  private def self.validate_entry!(requested : String, entries : Array({String, Int64})) : String
    name = requested.strip.gsub('\\', '/').lstrip('/')
    name = name[2..] if name.size > 2 && name[1] == ':' && name[0].letter?
    return name if entries.any? { |(entry_name, _)| entry_name == name }

    raise Error.new("entry_not_found", "The chosen start file is not in the archive")
  end

  private def self.validate_name!(name : String) : Nil
    if name.empty? || name.bytesize > MAX_PATH_LENGTH || name.includes?('\0')
      raise Error.new("invalid_archive", "The archive contains an invalid file name")
    end

    if name.starts_with?('/') || name.includes?('\\')
      raise Error.new("invalid_archive", "The archive contains an absolute path")
    end

    if name.matches?(/[\x00-\x1f<>:"|?*]/)
      raise Error.new("invalid_archive", "The archive contains a forbidden character in a file name")
    end

    parts = name.split('/')
    if parts.size > MAX_DEPTH
      raise Error.new("invalid_archive", "The archive is nested too deeply")
    end

    parts.each do |part|
      if part.empty? || part == "." || part == ".."
        raise Error.new("invalid_archive", "The archive contains a path that escapes the build directory")
      end
    end
  end

  private def self.ignored?(name : String) : Bool
    base = File.basename(name)
    name.starts_with?("__MACOSX/") || base == ".DS_Store" || base == "Thumbs.db"
  end
end
