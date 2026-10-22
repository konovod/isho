class ForumTopicRead < BaseModel
  table do
    belongs_to user : User
    belongs_to topic : ForumTopic
    # Number of posts the user has already seen, counting from the start of
    # the topic. A missing row means the topic was never opened.
    column read_count : Int32
  end
end
