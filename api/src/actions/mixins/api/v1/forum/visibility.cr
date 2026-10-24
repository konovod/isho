module Api::V1::Forum::Visibility
  # A topic attached to a project follows the same rules as the project: hidden
  # adult or too-AI-heavy projects stay hidden, and a draft topic is visible
  # only to the project owner.
  def forum_topic_visible?(topic : ForumTopic) : Bool
    forum_topic_visible_to?(topic, current_user?)
  end

  # Feeds pass `nil` because readers never send a session cookie.
  def forum_topic_visible_to?(topic : ForumTopic, viewer : User?) : Bool
    return true unless topic.project_id

    project = topic.project
    return false unless project
    return false unless project.content_visible_to?(viewer)
    return true if project.published?

    viewer.try(&.id) == project.user_id
  end

  def require_visible_forum_topic!(topic : ForumTopic) : Nil
    return if forum_topic_visible?(topic)

    raise Avram::RecordNotFoundError.new(ForumTopic.table_name, topic.slug)
  end
end
