module Api::V1::Forum::Visibility
  include Api::V1::Forum::Blocks

  # A topic attached to a project follows the same rules as the project: hidden
  # adult or too-AI-heavy projects stay hidden, and a draft topic is visible
  # only to the project owner. Topics and messages of blocked accounts are
  # hidden from the blocker as well.
  def forum_topic_visible?(topic : ForumTopic) : Bool
    return false if forum_blocks_user?(topic.user_id)

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

  def forum_post_visible?(post : ForumPost) : Bool
    !forum_blocks_user?(post.user_id)
  end

  def require_visible_forum_post!(post : ForumPost) : Nil
    return if forum_post_visible?(post)

    raise Avram::RecordNotFoundError.new(ForumPost.table_name, post.id.to_s)
  end
end
