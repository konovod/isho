module Api::V1::Forum::ReadState
  # Read markers for a page of topics. nil means "no user": the API then omits
  # unread state instead of pretending that everything is read.
  def forum_read_counts(topics : Array(ForumTopic)) : Hash(Int64, Int32)?
    user = current_user?
    return nil unless user

    counts = {} of Int64 => Int32
    topics.each { |topic| counts[topic.id] = 0 }
    return counts if topics.empty?

    ForumTopicReadQuery.new
      .for_user(user.id)
      .topic_id.in(topics.map(&.id))
      .results
      .each { |read| counts[read.topic_id] = read.read_count }

    counts
  end

  def forum_read_count(topic : ForumTopic) : Int32?
    user = current_user?
    return nil unless user

    ForumTopicReadQuery.new
      .for_user(user.id)
      .for_topic(topic.id)
      .first?
      .try(&.read_count) || 0
  end
end
