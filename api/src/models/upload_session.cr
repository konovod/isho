# A chunked upload that has started but not finished. While it exists, its
# declared bytes are already counted against the project and account quotas.
class UploadSession < BaseModel
  table do
    belongs_to user : User
    belongs_to project : Project
    column token : String
    column kind : String
    column filename : String
    column total_bytes : Int64
    column received_bytes : Int64
  end
end
