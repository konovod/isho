class ForumTopicQuery < ForumTopic::BaseQuery
  def newest_activity
    last_post_at.desc_order
  end

  def for_section(section_id : Int64)
    section_id(section_id)
  end

  def for_sections(section_ids : Array(Int64))
    section_id.in(section_ids)
  end

  def for_project(project_id : Int64)
    project_id(project_id)
  end

  def by_slug(slug : String)
    slug(slug)
  end

  # Topics with posts the user has not seen yet. A missing read row means the
  # topic was never opened, so everything in it counts as unread.
  def unread_for(user_id : Int64) : self
    where(<<-SQL, user_id)
      (forum_topics.replies_count + 1) > COALESCE((
        SELECT forum_topic_reads.read_count
        FROM forum_topic_reads
        WHERE forum_topic_reads.topic_id = forum_topics.id
          AND forum_topic_reads.user_id = ?
      ), 0)
    SQL
  end

  # Project discussions live in the public "projects" section. Draft projects
  # and content hidden by the viewer's preferences must not leak there, so only
  # topics of visible projects are listed.
  def with_visible_project(viewer : User?)
    join_project(ProjectQuery.new.visible_to(viewer))
  end
end
