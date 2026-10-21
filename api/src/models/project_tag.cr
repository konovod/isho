class ProjectTag < BaseModel
  table do
    belongs_to project : Project
    belongs_to tag : Tag
  end
end
