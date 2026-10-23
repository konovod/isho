class ForumAiAnswerQuery < ForumAiAnswer::BaseQuery
  def for_topic(topic_id : Int64)
    topic_id(topic_id)
  end
end
