class ForumPostReaction < BaseModel
  table do
    belongs_to post : ForumPost
    belongs_to user : User
    column kind : String
  end

  LIKE    = "like"
  DISLIKE = "dislike"
  KINDS   = [LIKE, DISLIKE]

  def like? : Bool
    kind == LIKE
  end

  def self.valid_kind?(kind : String) : Bool
    KINDS.includes?(kind)
  end
end
