class Devlog < BaseModel
  table do
    belongs_to project : Project
    column title : String
    column slug : String
    column body : String
  end
end
