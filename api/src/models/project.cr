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
    column nsfw : Bool
    column ai_usage : String
    column moderation_note : String?
    column moderated_at : Time?
    belongs_to moderated_by : User?
    has_many screenshots : Screenshot
    has_many downloads : Download
    has_many builds : Build
    has_many devlogs : Devlog
    has_many forum_topics : ForumTopic
    has_many jam_entries : JamEntry
    has_many project_tags : ProjectTag
    has_many tags : Tag, through: [:project_tags, :tag]
  end

  def published? : Bool
    status == "published"
  end

  def cover : Screenshot?
    screenshots.find(&.is_cover) || screenshots.first?
  end

  # Owners and moderators always see the project. Everybody else respects the
  # viewer's content preferences: visitors never see adult projects and
  # accounts can limit the AI usage level they want to see.
  def content_visible_to?(viewer : User?) : Bool
    return true if viewer && (viewer.id == user_id || viewer.moderator?)

    if nsfw
      return false unless viewer
      return false unless viewer.show_nsfw
    end

    return true unless viewer
    AppSettings.ai_usage_rank(ai_usage) <= AppSettings.ai_usage_rank(viewer.max_ai_usage)
  end
end
