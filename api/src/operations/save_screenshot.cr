class SaveScreenshot < Screenshot::SaveOperation
  attach image, process: true
  permit_columns caption, position, is_cover

  before_save do
    caption.value = caption.value.to_s.strip
    validate_size_of caption, max: 200
  end
end
