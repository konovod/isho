# Shows what the AI features spent today and what is waiting in the queue.
#
#   ./bin/tasks ai.stats
class Ai::StatsTask < LuckyTask::Task
  name "ai.stats"
  summary "Show AI jobs, tokens and the remaining daily budget"

  def call
    puts "Enabled: #{Ai.enabled? ? "yes" : "no (AI_API_KEY is not set)"}"
    puts "Model:   #{AppSettings.ai_model}"
    puts "Limits:  #{AppSettings.ai_daily_jobs} jobs, " \
         "#{AppSettings.ai_daily_input_tokens} input tokens, " \
         "#{AppSettings.ai_daily_output_tokens} output tokens per day"
    puts ""

    jobs, input, output = Ai::Budget.today
    puts "Today (UTC):"
    puts "  jobs:   #{jobs}"
    puts "  input:  #{input}"
    puts "  output: #{output}"
    puts ""

    rows = AppDatabase.run do |db|
      db.query_all(<<-SQL, Time.utc.at_beginning_of_day, as: {String, String, Int64, Int64, Int64})
        SELECT kind, status, COUNT(*), COALESCE(SUM(prompt_tokens), 0), COALESCE(SUM(completion_tokens), 0)
        FROM ai_jobs
        WHERE created_at >= $1
        GROUP BY kind, status
        ORDER BY kind, status
      SQL
    end

    if rows.empty?
      puts "No jobs today."
    else
      puts "By kind and status:"
      rows.each do |(kind, status, count, prompt, completion)|
        puts "  #{kind.ljust(13)} #{status.ljust(8)} #{count.to_s.rjust(5)}  " \
             "#{prompt.to_s.rjust(8)} in / #{completion.to_s.rjust(6)} out"
      end
    end

    queued = AiJobQuery.new.queued.select_count
    oldest = AiJobQuery.new.queued.oldest_first.first?
    puts ""
    puts "Queue: #{queued} job(s)"
    if oldest
      puts "Oldest: ##{oldest.id} #{oldest.kind}, waiting since #{oldest.run_after}"
    end

    failures = AiJobQuery.new.status("failed").recent_first.limit(10).results
    unless failures.empty?
      puts ""
      puts "Recent failures:"
      failures.each do |job|
        puts "  ##{job.id} #{job.kind} user #{job.user_id}: #{job.error}"
      end
    end
  end
end
