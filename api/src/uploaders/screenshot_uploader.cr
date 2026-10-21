struct ScreenshotUploader
  include Latch::Uploader

  struct Versions
    include Latch::Processor::Magick

    original resize: "1920x1920>", strip: true, quality: 85
    variant card, resize: "960x960>", strip: true, quality: 82
    variant thumb, resize: "480x480>", strip: true, quality: 80
  end

  process versions, using: Versions

  # Latch builds locations with File.join, which uses backslashes on Windows.
  # Storage IDs and public URLs must always use forward slashes.
  def generate_location(uploaded_file, metadata, **options) : String
    super.gsub('\\', '/')
  end
end
