class ForumTopicRead < BaseModel
  table do
    belongs_to user : User
    belongs_to topic : ForumTopic
    # Number of posts the user has already seen, counting from the start of
    # the topic. A missing row means the topic was never opened.
    column read_count : Int32
    # The post that was last seen. Unlike `read_count`, this id can ignore
    # posts by blocked authors when counting what is still unread.
    column last_post_id : Int64?
  end
end
