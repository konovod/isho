# Rows of `import_jobs`, written only here so status and timestamps stay
# consistent. The worker is the only writer after the request that queued it.
module Import::Jobs
  MAX_ATTEMPTS = 2

  def self.enqueue(user : User, source_url : String) : ImportJob
    SaveImportJob.create!(
      user_id: user.id,
      source_url: source_url,
      status: "queued",
      step: "fetch",
      attempts: 0,
      run_after: Time.utc,
      prompt_tokens: 0,
      completion_tokens: 0,
    )
  end

  # Takes a queued job and marks it running in one step. A job cancelled between
  # the query and this call is left alone.
  def self.claim(job : ImportJob) : ImportJob?
    claimed = nil

    AppDatabase.transaction do
      AppDatabase.run do |db|
        db.exec("SELECT id FROM import_jobs WHERE id = $1 FOR UPDATE", job.id)
      end

      fresh = ImportJobQuery.new.id(job.id).first?
      if fresh && fresh.status == "queued"
        claimed = SaveImportJob.update!(
          fresh,
          status: "running",
          step: "fetch",
          attempts: fresh.attempts + 1,
          started_at: Time.utc,
        )
      end
    end

    claimed
  end

  def self.step!(job : ImportJob, step : String) : ImportJob
    SaveImportJob.update!(job, step: step)
  end

  def self.complete!(
    job : ImportJob,
    project_id : Int64,
    prompt_tokens : Int32,
    completion_tokens : Int32,
    result : String? = nil,
  ) : ImportJob
    SaveImportJob.update!(
      job,
      status: "done",
      step: "done",
      project_id: project_id,
      finished_at: Time.utc,
      error: nil,
      result: result,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
    )
  end

  def self.skip!(
    job : ImportJob,
    reason : String,
    prompt_tokens : Int32 = 0,
    completion_tokens : Int32 = 0,
  ) : ImportJob
    SaveImportJob.update!(
      job,
      status: "skipped",
      finished_at: Time.utc,
      error: reason[0, 500],
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
    )
  end

  def self.fail!(job : ImportJob, message : String) : ImportJob
    SaveImportJob.update!(
      job,
      status: "failed",
      finished_at: Time.utc,
      error: message[0, 500],
    )
  end

  # A site that is down right now is worth one more try later.
  def self.retry_later!(job : ImportJob, message : String, delay : Time::Span) : ImportJob
    if job.attempts >= MAX_ATTEMPTS
      return fail!(job, message)
    end

    SaveImportJob.update!(
      job,
      status: "queued",
      step: "fetch",
      started_at: nil,
      run_after: Time.utc + delay,
      error: message[0, 500],
    )
  end

  # Called when the worker starts: a job left in "running" belongs to a process
  # that died, and no other worker is working on it.
  def self.recover! : Int32
    jobs = ImportJobQuery.new.running.results

    jobs.each do |job|
      SaveImportJob.update!(
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
        "DELETE FROM import_jobs WHERE finished_at IS NOT NULL AND finished_at < $1",
        before,
      ).rows_affected
    end
  end

  # Jobs that never started, for example after a crash before the worker picked
  # them up, must not sit in the queue forever.
  def self.abandon_stale(before : Time) : Int64
    AppDatabase.run do |db|
      db.exec(
        "UPDATE import_jobs SET status = 'failed', finished_at = $1, error = 'задача устарела' " \
        "WHERE status IN ('queued', 'running') AND created_at < $2",
        Time.utc, before,
      ).rows_affected
    end
  end
end
