class Api::V1::Jams::Banner < ApiAction
  include Api::V1::Jams::RequireOwner
  include Api::Auth::RequireConfirmedEmail

  post "/api/v1/jams/:slug/banner" do
    file = multipart? ? params.get_file?("image_file") : nil

    unless file
      return json ErrorSerializer.new(
        code: "validation_failed",
        message: "image_file is required",
        details: {"image_file" => ["is required"]},
      ), status: 422
    end

    if file.tempfile.size.to_i64 > AppSettings::JAM_BANNER_MAX_BYTES
      return json ErrorSerializer.new(
        code: "jam_banner_too_large",
        message: "Баннер должен быть не больше 5 МБ",
      ), status: 422
    end

    bytes = file.tempfile.size.to_i64
    unless StorageUsage.fits_account?(current_user.id, bytes) && StorageUsage.fits_server?(bytes)
      return json ErrorSerializer.new(
        code: "storage_quota_exceeded",
        message: "В хранилище не хватает места",
      ), status: 422
    end

    unless AppSettings::JAM_BANNER_TYPES.includes?(file.content_type.to_s.downcase)
      return json ErrorSerializer.new(
        code: "invalid_file_type",
        message: "Поддерживаются PNG, JPEG и WebP",
      ), status: 422
    end

    old_banner = jam.banner
    updated = SaveJamBanner.update!(jam, banner_file: file)
    old_banner.try(&.delete)

    json JamSerializer.new(reload_jam(updated), current_user?, detailed: true)
  end

  private def multipart? : Bool
    context.request.headers["Content-Type"]?
      .try(&.downcase.starts_with?("multipart/form-data")) || false
  end
end
