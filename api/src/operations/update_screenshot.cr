# A screenshot's caption and cover flag change without a new image, so this
# operation has no file attribute. `SaveScreenshot` does: handing it Lucky
# params makes Avram extract `image_file`, and Lucky parses any body as
# multipart while doing that, which fails on a JSON request.
class UpdateScreenshot < Screenshot::SaveOperation
  permit_columns caption, position, is_cover

  before_save do
    caption.value = caption.value.to_s.strip
    validate_size_of caption, max: 200
  end

  # A project has one cover. Clearing the others here keeps the switch inside
  # the operation's transaction, so a failure cannot leave two screenshots
  # marked as the cover.
  after_save do |record|
    clear_other_covers(record) if record.is_cover
  end

  private def clear_other_covers(record : Screenshot) : Nil
    ScreenshotQuery.new.project_id(record.project_id).results.each do |other|
      next if other.id == record.id || !other.is_cover
      Screenshot::SaveOperation.update!(other, is_cover: false)
    end
  end
end
