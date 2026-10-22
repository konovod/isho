class DeleteForumPost < Avram::Operation
  needs post : ForumPost

  def run
    topic = post.topic

    AppDatabase.transaction do
      ForumPost::DeleteOperation.delete!(post)

      remaining = ForumPostQuery.new
        .topic_id(topic.id)
        .newest_first
        .first?

      replies = topic.replies_count - 1
      replies = 0 if replies < 0

      ForumTopic::SaveOperation.update!(
        topic,
        replies_count: replies,
        last_post_at: remaining.try(&.created_at) || topic.created_at,
        last_post_user_id: remaining.try(&.user_id),
      )
    end
  end
end
