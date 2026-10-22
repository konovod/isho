class ForumTopicReadQuery < ForumTopicRead::BaseQuery
  def for_user(user_id : Int64)
    user_id(user_id)
  end

  def for_topic(topic_id : Int64)
    topic_id(topic_id)
  end
end
