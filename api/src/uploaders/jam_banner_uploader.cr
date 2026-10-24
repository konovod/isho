struct JamBannerUploader
  include Latch::Uploader

  struct Versions
    include Latch::Processor::Magick

    original resize: "1920x1080>", strip: true, quality: 85
    variant card, resize: "960x960>", strip: true, quality: 82
  end

  process versions, using: Versions

  # Latch builds locations with File.join, which uses backslashes on Windows.
  # Storage IDs and public URLs must always use forward slashes.
  def generate_location(uploaded_file, metadata, **options) : String
    super.gsub('\\', '/')
  end

  # See MediaFileExtension: without an extension the variants would be stored
  # inside the file instead of beside it.
  protected def file_extension(uploaded_file, metadata) : String?
    super || MediaFileExtension.for_content_type(uploaded_file.content_type)
  end
end
