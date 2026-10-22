# Removes everything a user wrote on the forum. A future account deletion flow
# must call this before deleting the user row, because database cascades would
# leave denormalized topic counters stale.
class DeleteUserContent < Avram::Operation
  needs user : User

  def run
    topics = ForumTopicQuery.new.user_id(user.id).results
    topic_ids = topics.map(&.id)

    # Posts in the user's own topics disappear together with the topics.
    posts = ForumPostQuery.new
      .user_id(user.id)
      .results
      .reject { |post| topic_ids.includes?(post.topic_id) }
    affected_topic_ids = posts.map(&.topic_id).uniq

    AppDatabase.transaction do
      topics.each { |topic| ForumTopic::DeleteOperation.delete!(topic) }
      posts.each { |post| ForumPost::DeleteOperation.delete!(post) }

      affected_topic_ids.each do |topic_id|
        recalculate(topic_id)
      end
    end
  end

  private def recalculate(topic_id : Int64) : Nil
    topic = ForumTopicQuery.new.id(topic_id).first?
    return unless topic

    remaining = ForumPostQuery.new.topic_id(topic_id).newest_first.first?

    unless remaining
      ForumTopic::DeleteOperation.delete!(topic)
      return
    end

    replies = ForumPostQuery.new.topic_id(topic_id).select_count - 1
    replies = 0_i64 if replies < 0

    ForumTopic::SaveOperation.update!(
      topic,
      replies_count: replies.to_i32,
      last_post_at: remaining.created_at,
      last_post_user_id: remaining.user_id,
    )
  end
end
