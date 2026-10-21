class Tag < BaseModel
  table do
    column name : String
    column slug : String
    has_many project_tags : ProjectTag
  end
end
