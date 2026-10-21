class CreateForumPost < Avram::Operation
  needs topic : ForumTopic
  needs user : User
  needs body : String
  needs quoted_post_id : Int64?

  def run
    post = nil

    AppDatabase.transaction do
      post = SaveForumPost.create!(
        topic_id: topic.id,
        user_id: user.id,
        body: body,
        quoted_post_id: quoted_post_id,
      )

      ForumTopic::SaveOperation.update!(
        topic,
        replies_count: topic.replies_count + 1,
        last_post_at: post.not_nil!.created_at,
      )
    end

    post.not_nil!
  end
end
