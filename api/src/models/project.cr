class Project < BaseModel
  table do
    belongs_to user : User
    column kind : String
    column title : String
    column slug : String
    column tagline : String?
    column description : String?
    column status : String
    column published_at : Time?
    has_many screenshots : Screenshot
    has_many downloads : Download
    has_many devlogs : Devlog
    has_many forum_topics : ForumTopic
    has_many project_tags : ProjectTag
    has_many tags : Tag, through: [:project_tags, :tag]
  end

  def published? : Bool
    status == "published"
  end

  def cover : Screenshot?
    screenshots.find(&.is_cover) || screenshots.first?
  end
end
