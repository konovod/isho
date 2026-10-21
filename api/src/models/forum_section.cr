class ForumSection < BaseModel
  table do
    column title : String
    column slug : String
    column description : String?
    column group_title : String?
    column position : Int32
    has_many topics : ForumTopic
  end
end
