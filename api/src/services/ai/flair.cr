# Builds a short characteristic from a user's latest forum posts. It is
# scheduled by the worker for active authors only, at most once a day.
module Ai::Flair
  # Do not spend the whole daily budget on the first tick after a deploy.
  MAX_JOBS_PER_TICK = 25

  def self.schedule(now : Time = Time.utc) : Int32
    return 0 unless Ai.enabled?

    user_ids = AppDatabase.run do |db|
      db.query_all(
        "SELECT DISTINCT user_id FROM forum_posts WHERE created_at >= $1 LIMIT 500",
        now - AppSettings::AI_FLAIR_ACTIVE_DAYS,
        as: Int64,
      )
    end

    queued = 0
    user_ids.each do |user_id|
      break if queued >= MAX_JOBS_PER_TICK

      user = UserQuery.new.id(user_id).first?
      next unless user
      next unless user.ai_flair_enabled
      next if fresh?(user, now)
      next if ForumPostQuery.new.by_user(user_id).select_count < AppSettings::AI_FLAIR_MIN_POSTS
      if at = user.ai_flair_at
        next if ForumPostQuery.new.by_user(user_id).since(at).select_count < AppSettings::AI_FLAIR_MIN_NEW_POSTS
      end
      next if AiJobQuery.new.of_kind("flair").user_id(user_id).queued.first?

      Ai::Jobs.enqueue("flair", user_id)
      queued += 1
    end

    queued
  end

  # A fresh flair is left alone: the worker only rebuilds it once the cooldown
  # has passed, so an active author costs one call a day at most.
  def self.fresh?(user : User, now : Time) : Bool
    at = user.ai_flair_at
    return false unless at
    now - at < AppSettings::AI_FLAIR_TTL
  end

  def self.perform(job : AiJob) : Nil
    user = UserQuery.new.id(job.user_id).first?
    unless user
      Ai::Jobs.skip!(job, "user deleted")
      return
    end

    unless user.ai_flair_enabled
      Ai::Jobs.skip!(job, "flair disabled by the user")
      return
    end

    if fresh?(user, Time.utc)
      Ai::Jobs.skip!(job, "flair is fresh")
      return
    end

    posts = ForumPostQuery.new.by_user(user.id).latest(AppSettings::AI_FLAIR_LOOKBACK_POSTS)
    if posts.size < AppSettings::AI_FLAIR_MIN_POSTS
      Ai::Jobs.skip!(job, "too few posts")
      return
    end

    snippets = [] of String
    total = 0
    posts.each do |post|
      snippet = post.body.gsub(/\s+/, " ").strip[0, AppSettings::AI_FLAIR_POST_CHARS]
      break if total + snippet.size > AppSettings::AI_FLAIR_MAX_INPUT_CHARS
      snippets << snippet
      total += snippet.size
    end

    if snippets.empty?
      Ai::Jobs.skip!(job, "no text to read")
      return
    end

    completion = Ai.complete(
      [
        Ai::Message.new("system", Ai::Prompts::FLAIR_SYSTEM),
        Ai::Message.new("user", Ai::Prompts.flair(snippets)),
      ],
      max_tokens: AppSettings::AI_FLAIR_MAX_TOKENS,
      temperature: 0.9,
      json_response: true,
    )

    usage = completion.usage
    value = Ai::Json.object(completion.text).try(&.["flair"]?).try(&.as_s?)
    flair = value.try { |text| Ai::Sanitize.flair(text) }

    unless flair
      Ai::Jobs.skip!(job, "unusable flair", usage.prompt_tokens, usage.completion_tokens)
      return
    end

    SaveUserAiFlair.update!(user, ai_flair: flair, ai_flair_at: Time.utc)
    Ai::Jobs.complete!(job, usage.prompt_tokens, usage.completion_tokens)
  rescue ex : Ai::Error
    Ai::Jobs.fail!(job, ex.message.to_s)
  end
end
