# Stored files for downloadable builds. Finished chunked uploads are moved
# into `build/<public_id>/files/<original name>`; nothing is processed, so a
# 300 MB archive never has to fit in memory.
struct BuildUploader
  include Latch::Uploader

  # Latch builds locations with File.join, which uses backslashes on Windows.
  # Storage IDs and public URLs must always use forward slashes.
  def generate_location(uploaded_file, metadata, **options) : String
    super.gsub('\\', '/')
  end
end
