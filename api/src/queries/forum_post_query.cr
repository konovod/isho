class ForumPostQuery < ForumPost::BaseQuery
  def chronological
    created_at.asc_order
  end

  def newest_first
    created_at.desc_order
  end

  def for_topic(topic_id : Int64)
    topic_id(topic_id)
  end

  def by_user(user_id : Int64)
    user_id(user_id)
  end

  # Messages written by an account the viewer blocked.
  def excluding_blocked_authors(blocker_id : Int64) : self
    where(<<-SQL, blocker_id)
      forum_posts.user_id NOT IN (
        SELECT user_blocks.blocked_user_id
        FROM user_blocks
        WHERE user_blocks.blocker_id = ?
      )
    SQL
  end

  def since(time : Time)
    created_at.gte(time)
  end

  # The latest messages, used to build a user's AI flair.
  def latest(limit : Int32)
    newest_first.limit(limit)
  end

  # The opening message of every given topic in one query, for feed previews.
  def first_for_topics(topic_ids : Array(Int64)) : self
    return id.eq(-1_i64) if topic_ids.empty?

    where(<<-SQL)
      forum_posts.id IN (
        SELECT MIN(first_posts.id)
        FROM forum_posts first_posts
        WHERE first_posts.topic_id = forum_posts.topic_id
      )
    SQL
      .topic_id.in(topic_ids)
  end
end
