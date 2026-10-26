# The daily ceiling for the whole server. A single account has its own quota;
# this one protects the key when many accounts ask at once.
module Ai::Budget
  SQL = <<-SQL
    SELECT COUNT(*), COALESCE(SUM(prompt_tokens), 0), COALESCE(SUM(completion_tokens), 0)
    FROM (
      SELECT prompt_tokens, completion_tokens
      FROM ai_jobs
      WHERE created_at >= $1
      UNION ALL
      SELECT prompt_tokens, completion_tokens
      FROM import_jobs
      WHERE created_at >= $1 AND status IN ('done', 'skipped', 'failed')
    ) AS jobs
    SQL

  def self.available? : Bool
    Ai.enabled? && !exhausted?
  end

  def self.exhausted? : Bool
    jobs, input, output = today
    jobs >= AppSettings.ai_daily_jobs ||
      input >= AppSettings.ai_daily_input_tokens ||
      output >= AppSettings.ai_daily_output_tokens
  end

  # Jobs, input tokens and output tokens since midnight UTC.
  def self.today : {Int64, Int64, Int64}
    AppDatabase.run do |db|
      db.query_one(SQL, Time.utc.at_beginning_of_day, as: {Int64, Int64, Int64})
    end
  end
end
