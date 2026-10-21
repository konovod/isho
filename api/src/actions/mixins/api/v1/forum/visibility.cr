module Api::V1::Forum::Visibility
  # A topic attached to a draft project is visible only to the project owner.
  def forum_topic_visible?(topic : ForumTopic) : Bool
    return true unless topic.project_id

    project = topic.project
    return false unless project
    return true if project.published?

    current_user?.try(&.id) == project.user_id
  end

  def require_visible_forum_topic!(topic : ForumTopic) : Nil
    return if forum_topic_visible?(topic)

    raise Avram::RecordNotFoundError.new(ForumTopic.table_name, topic.slug)
  end
end
