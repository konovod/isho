# Long-running loop behind isho-imports.service. One job at a time: a job
# downloads a page and up to six pictures, and a second one in parallel would
# only compete for the same bandwidth.
module Import::Worker
  def self.start(once : Bool = false, verbose : Bool = false) : Nil
    Import::Jobs.recover! unless once

    stopping = false
    {% unless flag?(:win32) %}
      Signal::TERM.trap { stopping = true }
      Signal::INT.trap { stopping = true }
    {% end %}

    if once
      processed = process_one(verbose)
      puts "Import worker: queue is empty" unless processed
      return
    end

    unless AppSettings.import_enabled?
      say "disabled: set AI_API_KEY (and keep IMPORT_ENABLED on) to turn imports on", verbose
      # Stay alive instead of letting systemd restart the unit in a loop.
      loop do
        break if stopping
        sleep 1.hour
        break if AppSettings.import_enabled?
      end
      return
    end

    say "started", verbose
    last_cleanup = Time.utc

    loop do
      break if stopping

      processed = process_one(verbose)
      now = Time.utc

      if now - last_cleanup >= 24.hours
        removed = Import::Jobs.cleanup(now - AppSettings::IMPORT_RETENTION)
        stale = Import::Jobs.abandon_stale(now - 1.day)
        say "removed #{removed} old jobs, abandoned #{stale} stale jobs", verbose
        last_cleanup = now
      end

      sleep(processed ? 1.second : 5.seconds)
    end

    say "stopped", verbose
  end

  # Processes at most one queued job. Returns false when the queue is empty.
  def self.process_one(verbose : Bool = false) : Bool
    return false unless AppSettings.import_enabled?

    next_job = ImportJobQuery.new.queued.due(Time.utc).oldest_first.first?
    return false unless next_job

    job = Import::Jobs.claim(next_job)
    # Cancelled between the query and the claim: nothing to do.
    return true unless job

    say "job ##{job.id} for user #{job.user_id}: #{job.source_url}", verbose

    begin
      Import::Runner.perform(job)
    rescue error
      Import::Jobs.fail!(job, "#{error.class}: #{error.message}")
      say "job ##{job.id} failed: #{error.class}: #{error.message}", true
    end

    true
  end

  private def self.say(message : String, verbose : Bool) : Nil
    puts "Import worker: #{message}" if verbose
  end
end
