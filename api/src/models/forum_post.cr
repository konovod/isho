class ForumPost < BaseModel
  table do
    belongs_to topic : ForumTopic
    belongs_to user : User
    column body : String
    column quoted_post_id : Int64?
    column quote_author_name : String?
    column quote_author_username : String?
    column quote_body : String?
  end

  def quoted? : Bool
    !quote_body.to_s.empty?
  end
end
