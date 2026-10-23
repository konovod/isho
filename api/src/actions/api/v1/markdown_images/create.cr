# Uploads an image for the Markdown editor. The action is not tied to a project
# or post: the returned URL is inserted into any Markdown text, so one file can
# be reused and drafts can contain images before they are saved.
class Api::V1::MarkdownImages::Create < ApiAction
  include Api::Auth::RequireNotBanned

  post "/api/v1/markdown_images" do
    file = multipart? ? params.get_file?("image_file") : nil

    unless file
      return json(ErrorSerializer.new(
        code: "validation_failed",
        message: "image_file is required",
        details: {"image_file" => ["is required"]},
      ), status: 422)
    end

    if file.tempfile.size.to_i64 > AppSettings::MARKDOWN_IMAGE_MAX_BYTES
      return json(ErrorSerializer.new(
        code: "file_too_large",
        message: "Images must be 10 MB or smaller",
      ), status: 422)
    end

    bytes = file.tempfile.size.to_i64
    unless StorageUsage.fits_account?(current_user.id, bytes) && StorageUsage.fits_server?(bytes)
      return json(ErrorSerializer.new(
        code: "storage_quota_exceeded",
        message: "The storage limit is used up",
      ), status: 422)
    end

    unless AppSettings::MARKDOWN_IMAGE_TYPES.includes?(file.content_type.to_s.downcase)
      return json(ErrorSerializer.new(
        code: "invalid_file_type",
        message: "Only JPEG, PNG, WebP and GIF images are supported",
      ), status: 422)
    end

    created = SaveMarkdownImage.create!(
      image_file: file,
      user_id: current_user.id,
    )

    # Latch promotes and processes the file after commit, so reload to get the
    # final URL.
    image = MarkdownImageQuery.new.id(created.id).first? || created
    json MarkdownImageSerializer.new(image), status: 201
  end

  # Lucky parses form data lazily and its file lookup raises for a JSON body,
  # so a plain request without a file should simply fail validation.
  private def multipart? : Bool
    context.request.headers["Content-Type"]?
      .try(&.downcase.starts_with?("multipart/form-data")) || false
  end
end
