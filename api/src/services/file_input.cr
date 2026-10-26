require "http/formdata"

# Bytes that arrive from an import are written to disk before they reach an
# operation, so this wraps the file that is already there. Avram needs a
# metadata object for its file attribute; Latch only needs the file and a name.
struct FileInput
  include Avram::Uploadable
  include Latch::UploadedFile

  getter tempfile : File
  getter filename : String
  getter metadata : HTTP::FormData::FileMetadata

  def initialize(@tempfile : File, @filename : String)
    @metadata = HTTP::FormData::FileMetadata.new(
      filename: @filename,
      size: @tempfile.size.to_u64,
    )
  end

  def blank? : Bool
    filename.blank?
  end

  def size : UInt64
    tempfile.size.to_u64
  end
end
