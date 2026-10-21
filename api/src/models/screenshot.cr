class Screenshot < BaseModel
  include Latch::Avram::Model

  table do
    belongs_to project : Project
    attach image : ScreenshotUploader::StoredFile?
    column caption : String?
    column position : Int32
    column is_cover : Bool
  end
end
