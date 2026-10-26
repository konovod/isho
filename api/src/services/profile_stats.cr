# Counters for a public profile. They describe only what the viewer can
# discover: drafts, adult projects and content hidden by the AI preference do
# not leak into the numbers.
module ProfileStats
  record Counts,
    projects : Int64,
    comments : Int64,
    likes_given : Int64,
    likes_received : Int64

  def self.for_user(user : User, viewer : User?) : Counts
    AppDatabase.run do |db|
      projects, comments, given, received = db.query_one(
        SQL,
        nsfw_allowed?(viewer),
        allowed_ai_levels(viewer),
        user.id,
        as: {Int64, Int64, Int64, Int64},
      )
      Counts.new(projects, comments, given, received)
    end
  end

  # Moderators see every published project, accounts respect their own
  # preferences, and visitors never see adult ones.
  private def self.nsfw_allowed?(viewer : User?) : Bool
    user = viewer
    return false unless user
    user.moderator? || user.show_nsfw
  end

  private def self.allowed_ai_levels(viewer : User?) : Array(String)
    user = viewer
    return AppSettings::AI_USAGE_LEVELS unless user
    return AppSettings::AI_USAGE_LEVELS if user.moderator?

    rank = AppSettings.ai_usage_rank(user.max_ai_usage)
    AppSettings::AI_USAGE_LEVELS[0..rank]
  end

  # Comments include the opening message of a topic: the forum counts it as a
  # post too. Received likes are likes minus dislikes on the same posts, so a
  # controversial author can get a negative number.
  private SQL = <<-SQL
    WITH visible_projects AS (
      SELECT p.id
      FROM projects p
      WHERE p.status = 'published'
        AND ($1::boolean OR p.nsfw = FALSE)
        AND p.ai_usage = ANY($2::text[])
    ),
    visible_topics AS (
      SELECT t.id
      FROM forum_topics t
      WHERE t.project_id IS NULL
         OR t.project_id IN (SELECT id FROM visible_projects)
    ),
    visible_posts AS (
      SELECT fp.id, fp.user_id
      FROM forum_posts fp
      JOIN visible_topics vt ON vt.id = fp.topic_id
    )
    SELECT
      (SELECT COUNT(*) FROM visible_projects)::bigint AS projects,
      (SELECT COUNT(*) FROM visible_posts WHERE user_id = $3)::bigint AS comments,
      (SELECT COUNT(*)
       FROM forum_post_reactions r
       JOIN visible_posts vp ON vp.id = r.post_id
       WHERE r.user_id = $3 AND r.kind = 'like')::bigint AS likes_given,
      (
        (SELECT COUNT(*)
         FROM forum_post_reactions r
         JOIN visible_posts vp ON vp.id = r.post_id
         WHERE vp.user_id = $3 AND r.kind = 'like')
        -
        (SELECT COUNT(*)
         FROM forum_post_reactions r
         JOIN visible_posts vp ON vp.id = r.post_id
         WHERE vp.user_id = $3 AND r.kind = 'dislike')
      )::bigint AS likes_received
    SQL
end
