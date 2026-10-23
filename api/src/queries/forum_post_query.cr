class ForumPostQuery < ForumPost::BaseQuery
  def chronological
    created_at.asc_order
  end

  def newest_first
    created_at.desc_order
  end

  def for_topic(topic_id : Int64)
    topic_id(topic_id)
  end

  def by_user(user_id : Int64)
    user_id(user_id)
  end

  def since(time : Time)
    created_at.gte(time)
  end

  # The latest messages, used to build a user's AI flair.
  def latest(limit : Int32)
    newest_first.limit(limit)
  end
end
