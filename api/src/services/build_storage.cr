require "file_utils"

# Files that back a Build: downloadable attachments through Latch and unpacked
# browser builds under public/media/web.
module BuildStorage
  WEB_DIRECTORY = File.join("public", "media", "web")

  # Latch's uploader interface needs a tempfile and a filename; the assembled
  # chunk file already is both.
  private struct UploadAdapter
    include Latch::UploadedFile

    getter tempfile : File
    getter filename : String

    def initialize(@tempfile : File, @filename : String)
    end

    def size : UInt64
      tempfile.size.to_u64
    end
  end

  def self.web_dir(public_id : String) : String
    File.join(WEB_DIRECTORY, safe_public_id(public_id))
  end

  def self.web_exists?(public_id : String) : Bool
    File.directory?(web_dir(public_id))
  end

  # Moves the finished chunk file into Latch storage and returns the attachment
  # to put on the row. The file is renamed, not copied, so peak disk usage is
  # one file rather than two.
  def self.store_file(part_path : String, filename : String, public_id : String) : BuildUploader::StoredFile
    uploader = BuildUploader.new("store")
    safe = safe_filename(filename)
    location = File.join("build", safe_public_id(public_id), "files", safe).gsub('\\', '/')

    file = File.open(part_path, "rb")
    begin
      metadata = uploader.extract_metadata(UploadAdapter.new(file, safe))
      uploader.storage.move(file, location, metadata: metadata)
      BuildUploader::StoredFile.new(id: location, storage_key: "store", metadata: metadata)
    ensure
      file.close
    end
  end

  def self.delete_files(build : Build) : Nil
    build.stored_file.try(&.delete)
    remove_web_dir(build.public_id) if build.web?
  end

  def self.remove_web_dir(public_id : String) : Nil
    FileUtils.rm_rf(web_dir(public_id))
  end

  # Keeps the original name for the download link but strips anything that is
  # awkward in a URL or forbidden on Windows.
  def self.safe_filename(name : String) : String
    base = File.basename(name.gsub('\\', '/'))
    base = base.gsub(/[\x00-\x1f\/\\:*?"<>|]/, "_").strip.lstrip('.')
    base = "build" if base.empty? || base == "." || base == ".."
    base = base[0, 100] if base.size > 100
    base
  end

  def self.safe_public_id(public_id : String) : String
    cleaned = public_id.gsub(/[^A-Za-z0-9-]/, "")
    cleaned.empty? ? "build" : cleaned
  end
end
