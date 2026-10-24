# A build hosted by isho: either a downloadable file or an unpacked browser
# build served from /media/web/<public_id>. External links stay in Download.
class Build < BaseModel
  include Latch::Avram::Model

  table do
    belongs_to project : Project
    column public_id : String
    column kind : String
    column label : String
    column platform : String?
    column version : String?
    attach stored_file : BuildUploader::StoredFile?
    column entry_path : String?
    column size_bytes : Int64
    column downloads_count : Int64
    column launches_count : Int64
  end

  def web? : Bool
    kind == "web"
  end
end
