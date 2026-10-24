# Counts are derived from the reaction rows: deleting a user or a post then
# cannot leave a stale number behind.
module ForumReactions
  record Summary, likes : Int32, dislikes : Int32, my_reaction : String? do
    def self.empty : Summary
      new(0, 0, nil)
    end
  end

  # Summaries for a page of posts in one query, keyed by post id.
  def self.summaries(post_ids : Array(Int64), user_id : Int64?) : Hash(Int64, Summary)
    result = {} of Int64 => Summary
    post_ids.each { |id| result[id] = Summary.empty }
    return result if post_ids.empty?

    placeholders = post_ids.map_with_index { |_, index| "$#{index + 1}" }.join(", ")
    args = post_ids.map { |id| id.as(DB::Any) }
    reacted = "FALSE"

    if id = user_id
      args << id.as(DB::Any)
      reacted = "BOOL_OR(user_id = $#{post_ids.size + 1})"
    end

    sql = <<-SQL
      SELECT post_id, kind, COUNT(*)::bigint, #{reacted}
      FROM forum_post_reactions
      WHERE post_id IN (#{placeholders})
      GROUP BY post_id, kind
    SQL

    AppDatabase.run do |db|
      db.query_all(sql, args: args, as: {Int64, String, Int64, Bool}).each do |row|
        post_id, kind, total, mine = row
        current = result[post_id]
        next unless current

        result[post_id] = case kind
                          when ForumPostReaction::LIKE
                            Summary.new(total.to_i32, current.dislikes, mine ? ForumPostReaction::LIKE : current.my_reaction)
                          when ForumPostReaction::DISLIKE
                            Summary.new(current.likes, total.to_i32, mine ? ForumPostReaction::DISLIKE : current.my_reaction)
                          else
                            current
                          end
      end
    end

    result
  end

  def self.summary(post_id : Int64, user_id : Int64?) : Summary
    summaries([post_id], user_id)[post_id]? || Summary.empty
  end
end
