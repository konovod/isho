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
end
