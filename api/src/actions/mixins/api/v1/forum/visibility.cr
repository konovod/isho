module Api::V1::Forum::Visibility
  # A topic attached to a project follows the same rules as the project: hidden
  # adult or too-AI-heavy projects stay hidden, and a draft topic is visible
  # only to the project owner.
  def forum_topic_visible?(topic : ForumTopic) : Bool
    return true unless topic.project_id

    project = topic.project
    return false unless project
    return false unless project.content_visible_to?(current_user?)
    return true if project.published?

    current_user?.try(&.id) == project.user_id
  end

  def require_visible_forum_topic!(topic : ForumTopic) : Nil
    return if forum_topic_visible?(topic)

    raise Avram::RecordNotFoundError.new(ForumTopic.table_name, topic.slug)
  end
end
