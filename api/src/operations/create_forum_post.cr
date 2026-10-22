class CreateForumPost < Avram::Operation
  needs topic : ForumTopic
  needs user : User
  needs body : String
  needs quoted_post_id : Int64?
  needs quote_text : String?

  def run
    post = nil

    AppDatabase.transaction do
      post = SaveForumPost.create!(
        topic_id: topic.id,
        user_id: user.id,
        body: body,
        quoted_post_id: quoted_post_id,
        quote_text: quote_text || "",
      )

      ForumTopic::SaveOperation.update!(
        topic,
        replies_count: topic.replies_count + 1,
        last_post_at: post.not_nil!.created_at,
        last_post_user_id: user.id,
      )
    end

    post.not_nil!
  end
end
