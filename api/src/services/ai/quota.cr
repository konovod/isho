# Per-user daily counters. The upsert checks the limit and increments in one
# statement, so two requests fired at the same moment cannot both pass.
module Ai::Quota
  SQL = <<-SQL
    INSERT INTO ai_usages (user_id, kind, day, used, created_at, updated_at)
    VALUES ($1, $2, $3, 1, $4, $4)
    ON CONFLICT (user_id, kind, day)
    DO UPDATE SET used = ai_usages.used + 1, updated_at = EXCLUDED.updated_at
    WHERE ai_usages.used < $5
    RETURNING used
    SQL

  def self.day : Time
    Time.utc.at_beginning_of_day
  end

  # Returns true when the call is allowed and records it. The global budget is
  # checked as well, so a quota never buys tokens the server cannot spend.
  def self.consume(user : User, kind : String, limit : Int32) : Bool
    return false unless Ai::Budget.available?

    now = Time.utc
    result = AppDatabase.run do |db|
      db.query_one?(SQL, user.id, kind, day, now, limit, as: Int32)
    end

    !result.nil?
  end

  def self.left(user : User, kind : String, limit : Int32) : Int32
    used = AiUsageQuery.new.for_user(user.id).of_kind(kind).on(day).first?.try(&.used) || 0
    remaining = limit - used
    remaining.positive? ? remaining : 0
  end
end
