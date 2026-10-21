class ForumTopic < BaseModel
  table do
    belongs_to section : ForumSection
    belongs_to user : User
    belongs_to project : Project?
    column title : String
    column slug : String
    column replies_count : Int32
    column last_post_at : Time
    has_many posts : ForumPost
  end

  def total_posts : Int32
    replies_count + 1
  end
end
