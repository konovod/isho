struct MarkdownImageUploader
  include Latch::Uploader

  struct Versions
    include Latch::Processor::Magick

    # ImageMagick processes every frame of an animated GIF, so delays and the
    # loop flag survive the resize; there is no need to coalesce frames.
    original resize: "1920x1920>", strip: true, quality: 85
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
