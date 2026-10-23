class ForumSection < BaseModel
  table do
    column title : String
    column slug : String
    column description : String?
    column group_title : String?
    column position : Int32
    # Moderators can turn AI answers off per section; "projects" is always off.
    column ai_answers_enabled : Bool
    has_many topics : ForumTopic
  end
end
