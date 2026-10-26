module Api::V1::Forum::Lookup
  def find_forum_section!(slug : String) : ForumSection
    ForumSectionQuery.new.by_slug(slug).preload_parent.first? || raise Avram::RecordNotFoundError.new(ForumSection.table_name, slug)
  end

  def find_forum_topic!(id : String) : ForumTopic
    ForumTopicQuery.new
      .id(id)
      .preload_user
      .preload_section(ForumSectionQuery.new.preload_parent)
      .preload_project
      .preload_last_post_user
      .first? || raise Avram::RecordNotFoundError.new(ForumTopic.table_name, id)
  end

  def find_forum_topic!(section : ForumSection, slug : String) : ForumTopic
    ForumTopicQuery.new
      .for_section(section.id)
      .by_slug(slug)
      .preload_user
      .preload_section(ForumSectionQuery.new.preload_parent)
      .preload_project
      .preload_last_post_user
      .first? || raise Avram::RecordNotFoundError.new(ForumTopic.table_name, slug)
  end

  def find_forum_post!(id : String) : ForumPost
    ForumPostQuery.new
      .id(id)
      .preload_user
      .preload_topic(ForumTopicQuery.new.preload_project)
      .first? || raise Avram::RecordNotFoundError.new(ForumPost.table_name, id)
  end

  def reload_forum_topic(topic : ForumTopic) : ForumTopic
    ForumTopicQuery.new
      .id(topic.id)
      .preload_user
      .preload_section(ForumSectionQuery.new.preload_parent)
      .preload_project
      .preload_last_post_user
      .first? || raise Avram::RecordNotFoundError.new(ForumTopic.table_name, topic.id.to_s)
  end

  # Page the quoted post is on, so a quote can link back to the message even
  # when it is no longer on the page it was quoted from. Posts are appended in
  # chronological order, but deletions shift the numbering, so the page is
  # recalculated on read instead of being stored with the snapshot. When the
  # viewer has a blacklist, only visible posts count.
  def forum_quote_page(post : ForumPost, blocker_id : Int64? = nil) : Int32?
    quoted_id = post.quoted_post_id
    return unless quoted_id

    quoted = ForumPostQuery.new.id(quoted_id).first?
    return unless quoted

    query = ForumPostQuery.new
      .for_topic(post.topic_id)
      .created_at.lte(quoted.created_at)
    query = query.excluding_blocked_authors(blocker_id) if blocker_id
    position = query.select_count

    ((position - 1) // AppSettings::FORUM_POSTS_PER_PAGE).to_i + 1
  end

  def reload_forum_post(post : ForumPost) : ForumPost
    ForumPostQuery.new
      .id(post.id)
      .preload_user
      .first? || raise Avram::RecordNotFoundError.new(ForumPost.table_name, post.id.to_s)
  end
end
