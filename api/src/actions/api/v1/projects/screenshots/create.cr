class Api::V1::Projects::Screenshots::Create < ApiAction
  include Api::V1::Projects::RequireOwner

  post "/api/v1/projects/:slug/screenshots" do
    file = params.get_file?("image_file")

    unless file
      return json(ErrorSerializer.new(
        code: "validation_failed",
        message: "image_file is required",
        details: {"image_file" => ["is required"]},
      ), status: 422)
    end

    if file.tempfile.size.to_i64 > AppSettings::SCREENSHOT_MAX_BYTES
      return json(ErrorSerializer.new(
        code: "file_too_large",
        message: "Screenshots must be 10 MB or smaller",
      ), status: 422)
    end

    bytes = file.tempfile.size.to_i64
    unless StorageUsage.fits_account?(current_user.id, bytes) && StorageUsage.fits_server?(bytes)
      return json(ErrorSerializer.new(
        code: "storage_quota_exceeded",
        message: "The storage limit is used up",
      ), status: 422)
    end

    unless %w[image/jpeg image/png image/webp].includes?(file.content_type.to_s.downcase)
      return json(ErrorSerializer.new(
        code: "invalid_file_type",
        message: "Only JPEG, PNG and WebP images are supported",
      ), status: 422)
    end

    count = ScreenshotQuery.new.project_id(project.id).select_count

    if count >= AppSettings::MAX_SCREENSHOTS
      return json(ErrorSerializer.new(
        code: "screenshot_limit_reached",
        message: "A project can have at most #{AppSettings::MAX_SCREENSHOTS} screenshots",
      ), status: 422)
    end

    created = SaveScreenshot.create!(
      image_file: file,
      caption: params.get?("caption"),
      project_id: project.id,
      position: count.to_i32,
      is_cover: count == 0,
    )

    # Latch promotes the file after commit, so reload to get final URLs.
    screenshot = ScreenshotQuery.new.id(created.id).first? || created
    json ScreenshotSerializer.new(screenshot), status: 201
  end
end
