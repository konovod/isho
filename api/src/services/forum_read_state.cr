# Forum counters for a viewer with a non-empty blacklist. Only posts by
# visible authors count towards pagination and unread state; the public
# counters on a topic and a section still include everything.
module ForumReadState
  record State,
    visible_total : Int32,
    unread_count : Int32,
    first_unread_post_id : Int64?,
    first_unread_page : Int32

  def self.for_topics(topic_ids : Array(Int64), viewer_id : Int64) : Hash(Int64, State)
    states = {} of Int64 => State
    topic_ids.each { |id| states[id] = State.new(0, 0, nil, 1) }
    return states if topic_ids.empty?

    rows = AppDatabase.run do |db|
      db.query_all(SQL, topic_ids, viewer_id, as: {Int64, Int64, Int64, Int64, Int64?})
    end

    per_page = AppSettings::FORUM_POSTS_PER_PAGE
    rows.each do |row|
      topic_id, visible_total, visible_before, unread, first_unread_id = row
      page = unread.positive? ? (visible_before // per_page).to_i + 1 : 1
      states[topic_id] = State.new(
        visible_total: visible_total.to_i32,
        unread_count: unread.to_i32,
        first_unread_post_id: first_unread_id,
        first_unread_page: page,
      )
    end

    states
  end

  # Posts of the requested topics, without posts of blocked authors, split at
  # the last seen post id. `visible_before` gives the position of the first
  # unread post in the visible sequence.
  private SQL = <<-SQL
    WITH visible_posts AS (
      SELECT forum_posts.id, forum_posts.topic_id
      FROM forum_posts
      WHERE forum_posts.topic_id = ANY($1::bigint[])
        AND forum_posts.user_id NOT IN (
          SELECT user_blocks.blocked_user_id
          FROM user_blocks
          WHERE user_blocks.blocker_id = $2
        )
    )
    SELECT
      topics.id,
      COUNT(visible_posts.id)::bigint AS visible_total,
      COUNT(visible_posts.id) FILTER (
        WHERE visible_posts.id <= COALESCE(reads.last_post_id, 0)
      )::bigint AS visible_before,
      COUNT(visible_posts.id) FILTER (
        WHERE visible_posts.id > COALESCE(reads.last_post_id, 0)
      )::bigint AS unread,
      MIN(visible_posts.id) FILTER (
        WHERE visible_posts.id > COALESCE(reads.last_post_id, 0)
      ) AS first_unread_id
    FROM unnest($1::bigint[]) AS topics(id)
    LEFT JOIN forum_topic_reads reads
      ON reads.topic_id = topics.id AND reads.user_id = $2
    LEFT JOIN visible_posts ON visible_posts.topic_id = topics.id
    GROUP BY topics.id, reads.last_post_id
    SQL
end
