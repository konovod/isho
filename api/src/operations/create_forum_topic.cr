class CreateForumTopic < Avram::Operation
  needs section : ForumSection
  needs user : User
  needs project : Project?
  needs title : String
  needs body : String

  def run
    topic = nil

    AppDatabase.transaction do
      topic = SaveForumTopic.create!(
        section_id: section.id,
        user_id: user.id,
        project_id: project.try(&.id),
        title: title,
        replies_count: 0,
        last_post_at: Time.utc,
      )

      SaveForumPost.create!(
        topic_id: topic.not_nil!.id,
        user_id: user.id,
        body: body,
      )
    end

    topic.not_nil!
  end
end
