# Latch takes a file's extension from the uploaded filename and builds the
# locations of processed variants from the stored id. A browser can send a
# file without an extension, which would leave both without one, and a
# variant would then land at "<id>/card" — inside the file itself. The upload
# actions validate the content type, so use it as the fallback.
module MediaFileExtension
  EXTENSIONS = {
    "image/jpeg" => "jpg",
    "image/png"  => "png",
    "image/webp" => "webp",
    "image/gif"  => "gif",
  }

  def self.for_content_type(content_type : String?) : String?
    mime = content_type.to_s.split(';').first?.try(&.strip.downcase)
    mime ? EXTENSIONS[mime]? : nil
  end
end
