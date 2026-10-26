require "file"

# Downloads the screenshots an import picked and stores them as ordinary
# Screenshot rows, so the existing uploader, quotas and serializers apply.
#
# One broken picture never fails the whole import: it is skipped and the rest
# still arrive.
module Import::Images
  DIRECTORY = "tmp/imports"

  def self.attach(project : Project, user_id : Int64, urls : Array(String)) : Int32
    Dir.mkdir_p(DIRECTORY)
    base = ScreenshotQuery.new.project_id(project.id).select_count.to_i32
    saved = 0

    urls.first(AppSettings::IMPORT_MAX_IMAGES).each do |url|
      next unless attach_one(project, user_id, url, base + saved)
      saved += 1
    end

    saved
  end

  private def self.attach_one(project : Project, user_id : Int64, url : String, position : Int32) : Bool
    fetched = Import::Fetcher.image(url)
    info = Import::ImageSize.inspect(fetched.body)
    return false unless info

    size = fetched.body.size.to_i64
    return false unless StorageUsage.fits_account?(user_id, size)
    return false unless StorageUsage.fits_server?(size)

    path = File.join(DIRECTORY, "#{Random::Secure.urlsafe_base64(16)}.#{info.extension}")
    File.open(path, "wb") { |io| io.write(fetched.body) }

    file = File.open(path, "rb")
    begin
      SaveScreenshot.create!(
        image_file: FileInput.new(file, "screenshot.#{info.extension}"),
        project_id: project.id,
        position: position,
        is_cover: position == 0,
      )
      true
    ensure
      file.close
      File.delete?(path)
    end
  rescue Import::Failed | Import::Unavailable | IO::Error
    false
  end
end
