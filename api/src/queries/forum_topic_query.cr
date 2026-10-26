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

  # Topics started by an account the viewer blocked.
  def excluding_blocked_authors(blocker_id : Int64) : self
    where(<<-SQL, blocker_id)
      forum_topics.user_id NOT IN (
        SELECT user_blocks.blocked_user_id
        FROM user_blocks
        WHERE user_blocks.blocker_id = ?
      )
    SQL
  end

  # The block-aware version of `unread_for`: only posts by visible authors
  # after the last seen post count, so a blocked reply never lights a badge.
  def unread_visible_for(user_id : Int64) : self
    where(<<-SQL, user_id, user_id, user_id)
      forum_topics.user_id NOT IN (
        SELECT user_blocks.blocked_user_id
        FROM user_blocks
        WHERE user_blocks.blocker_id = ?
      )
      AND EXISTS (
        SELECT 1
        FROM forum_posts unread_posts
        WHERE unread_posts.topic_id = forum_topics.id
          AND unread_posts.user_id NOT IN (
            SELECT user_blocks.blocked_user_id
            FROM user_blocks
            WHERE user_blocks.blocker_id = ?
          )
          AND unread_posts.id > COALESCE((
            SELECT forum_topic_reads.last_post_id
            FROM forum_topic_reads
            WHERE forum_topic_reads.topic_id = forum_topics.id
              AND forum_topic_reads.user_id = ?
          ), 0)
      )
    SQL
  end
end
