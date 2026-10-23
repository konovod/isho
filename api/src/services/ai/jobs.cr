# Small helpers around the ai_jobs rows. The operation is the only place that
# writes the row, so status and timestamps stay consistent.
module Ai::Jobs
  def self.enqueue(kind : String, user_id : Int64, topic_id : Int64? = nil, run_after : Time = Time.utc) : AiJob
    SaveAiJob.create!(
      kind: kind,
      user_id: user_id,
      topic_id: topic_id,
      status: "queued",
      attempts: 0,
      run_after: run_after,
      prompt_tokens: 0,
      completion_tokens: 0,
    )
  end

  def self.start!(job : AiJob) : AiJob
    AiJob::SaveOperation.update!(
      job,
      status: "running",
      attempts: job.attempts + 1,
      started_at: Time.utc,
    )
  end

  def self.complete!(job : AiJob, prompt_tokens : Int32, completion_tokens : Int32) : AiJob
    AiJob::SaveOperation.update!(
      job,
      status: "done",
      finished_at: Time.utc,
      error: nil,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
    )
  end

  def self.skip!(job : AiJob, reason : String, prompt_tokens : Int32 = 0, completion_tokens : Int32 = 0) : AiJob
    AiJob::SaveOperation.update!(
      job,
      status: "skipped",
      finished_at: Time.utc,
      error: reason[0, 500],
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
    )
  end

  def self.fail!(job : AiJob, message : String) : AiJob
    AiJob::SaveOperation.update!(
      job,
      status: "failed",
      finished_at: Time.utc,
      error: message[0, 500],
    )
  end

  # Called when the worker starts: a job left in "running" belongs to a process
  # that died, and no other worker can be working on it.
  def self.recover! : Int32
    jobs = AiJobQuery.new.running.results

    jobs.each do |job|
      AiJob::SaveOperation.update!(
        job,
        status: "queued",
        started_at: nil,
        error: "recovered after restart",
      )
    end

    jobs.size
  end

  def self.cleanup(before : Time) : Int64
    AppDatabase.run do |db|
      db.exec(
        "DELETE FROM ai_jobs WHERE finished_at IS NOT NULL AND finished_at < $1",
        before,
      ).rows_affected
    end
  end
end
