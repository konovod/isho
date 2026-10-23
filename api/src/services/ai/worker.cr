# Long-running loop behind isho-ai.service. One job at a time: two calls in
# parallel would only burn the budget faster, and a forum answer is not urgent.
module Ai::Worker
  def self.start(once : Bool = false, verbose : Bool = false) : Nil
    Ai::Jobs.recover! unless once

    stopping = false
    {% unless flag?(:win32) %}
      Signal::TERM.trap { stopping = true }
      Signal::INT.trap { stopping = true }
    {% end %}

    if once
      processed = process_one(verbose)
      puts "AI worker: queue is empty" unless processed
      return
    end

    unless Ai.enabled?
      say "disabled: set AI_API_KEY to turn AI on", verbose
      # Stay alive instead of letting systemd restart the unit in a loop. A
      # deploy that adds the key restarts the service anyway.
      loop do
        break if stopping
        sleep 1.hour
        break if Ai.enabled?
      end
      return
    end

    say "started (model #{AppSettings.ai_model})", verbose
    last_flair_schedule = Time.utc - 1.hour
    last_cleanup = Time.utc

    loop do
      break if stopping

      if Ai::Budget.exhausted?
        say "daily budget is used up, sleeping", verbose
        sleep 1.minute
        next
      end

      processed = process_one(verbose)
      now = Time.utc

      if now - last_flair_schedule >= 1.hour
        queued = Ai::Flair.schedule(now)
        say "scheduled #{queued} flair jobs", verbose if queued > 0
        last_flair_schedule = now
      end

      if now - last_cleanup >= 24.hours
        removed = Ai::Jobs.cleanup(now - AppSettings::AI_RETENTION)
        say "removed #{removed} old jobs", verbose
        last_cleanup = now
      end

      sleep(processed ? 1.second : 5.seconds)
    end

    say "stopped", verbose
  end

  # Processes at most one queued job. Returns false when the queue is empty.
  def self.process_one(verbose : Bool = false) : Bool
    job = AiJobQuery.new.queued.due(Time.utc).oldest_first.first?
    return false unless job

    running = Ai::Jobs.start!(job)
    say "job ##{running.id} #{running.kind} for user #{running.user_id}", verbose

    begin
      case running.kind
      when "forum_answer"
        Ai::ForumAnswer.perform(running)
      when "flair"
        Ai::Flair.perform(running)
      else
        Ai::Jobs.skip!(running, "unknown kind")
      end
    rescue ex
      Ai::Jobs.fail!(running, "#{ex.class}: #{ex.message}")
      say "job ##{running.id} failed: #{ex.class}: #{ex.message}", true
    end

    true
  end

  private def self.say(message : String, verbose : Bool) : Nil
    puts "AI worker: #{message}" if verbose
  end
end
