module Api::V1::Forum::Lookup
  def find_forum_section!(slug : String) : ForumSection
    ForumSectionQuery.new.by_slug(slug).first? || raise Avram::RecordNotFoundError.new(ForumSection.table_name, slug)
  end

  def find_forum_topic!(id : String) : ForumTopic
    ForumTopicQuery.new
      .id(id)
      .preload_user
      .preload_section
      .preload_project
      .first? || raise Avram::RecordNotFoundError.new(ForumTopic.table_name, id)
  end

  def find_forum_topic!(section : ForumSection, slug : String) : ForumTopic
    ForumTopicQuery.new
      .for_section(section.id)
      .by_slug(slug)
      .preload_user
      .preload_section
      .preload_project
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
      .preload_section
      .preload_project
      .first? || raise Avram::RecordNotFoundError.new(ForumTopic.table_name, topic.id.to_s)
  end

  def reload_forum_post(post : ForumPost) : ForumPost
    ForumPostQuery.new
      .id(post.id)
      .preload_user
      .first? || raise Avram::RecordNotFoundError.new(ForumPost.table_name, post.id.to_s)
  end
end
