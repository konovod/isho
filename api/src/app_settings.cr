module AppSettings
  SESSION_TTL           = 30.days
  SCREENSHOT_MAX_BYTES  = 10_000_000_i64
  SCREENSHOTS_PER_PAGE  =             24
  PROJECTS_PER_PAGE     =             24
  MAX_SCREENSHOTS       =             20
  MAX_DOWNLOADS         =             20
  MAX_EXTERNAL_URL_SIZE =           2048

  # Hosted builds. Uploads are chunked because Lucky reads a whole request
  # body into memory, so one 300 MB POST would not survive the prototype
  # server (709 MB RAM next to Nuxt).
  UPLOAD_CHUNK_BYTES      =   8_000_000_i64
  BUILD_MAX_BYTES         = 300_000_000_i64
  MAX_BUILDS              =              10
  UPLOAD_SESSION_TTL      = 2.hours
  STORAGE_DEFAULT_PROJECT =    300_000_000_i64
  STORAGE_DEFAULT_ACCOUNT =  1_000_000_000_i64
  STORAGE_DEFAULT_SERVER  = 12_000_000_000_i64
  STORAGE_DEFAULT_RESERVE =  2_000_000_000_i64
  FORUM_TOPICS_PER_PAGE   =                 25
  FORUM_POSTS_PER_PAGE    =                 20
  FORUM_POST_MAX_CHARS    =             20_000
  FORUM_QUOTE_MAX_CHARS   =              2_000
  FORUM_TOPIC_TITLE_MAX   =                160
  # Inline images in project descriptions, devlogs and forum posts. GIFs are
  # allowed as-is: ImageMagick keeps their frames and delays when resizing.
  MARKDOWN_IMAGE_MAX_BYTES = 10_000_000_i64
  MARKDOWN_IMAGE_TYPES     = %w[
    image/jpeg image/png image/webp image/gif
  ]
  THEMES = %w[light dark]

  # AI involvement, ordered from the least to the most. `max_ai_usage` on a
  # user is the highest level they want to see.
  AI_USAGE_LEVELS = %w[ai_free partial significant full]

  # AI on the forum. Every feature stays off without a key, and the daily
  # budgets below are the hard stop when someone tries to use the forum as a
  # free code assistant.
  AI_FORUM_ANSWERS_PER_DAY       =  3
  AI_SUGGESTIONS_PER_DAY         = 30
  AI_ANSWER_MIN_ACCOUNT_AGE      = 3.days
  AI_ANSWER_MIN_POSTS            =      5
  AI_ANSWER_MAX_INPUT_CHARS      =  3_500
  AI_ANSWER_MAX_CHARS            =  4_000
  AI_ANSWER_MAX_TOKENS           =    450
  AI_SUGGESTION_MAX_INPUT_CHARS  =  2_000
  AI_SUGGESTION_MAX_TOKENS       =    120
  AI_SUGGESTION_MIN_CONFIDENCE   =    0.6
  AI_FLAIR_MAX_CHARS             =     64
  AI_FLAIR_MIN_POSTS             =     10
  AI_FLAIR_MIN_NEW_POSTS         =      3
  AI_FLAIR_LOOKBACK_POSTS        =    100
  AI_FLAIR_POST_CHARS            =    300
  AI_FLAIR_MAX_INPUT_CHARS       = 20_000
  AI_FLAIR_MAX_TOKENS            =     40
  AI_FLAIR_ACTIVE_DAYS           = 7.days
  AI_FLAIR_TTL                   = 24.hours
  AI_RETENTION                   = 30.days
  AI_DEFAULT_DAILY_JOBS          =           200
  AI_DEFAULT_DAILY_INPUT_TOKENS  = 1_500_000_i64
  AI_DEFAULT_DAILY_OUTPUT_TOKENS =   300_000_i64
  RESERVED_USERNAMES             = %w[
    admin api dashboard login logout me new settings sign_in sign_up
    projects users assets articles jams forum support help about terms privacy
  ]

  # Email confirmation. `EMAIL_CONFIRMATION=off` turns the requirement off
  # (useful locally and while a mail transport is not configured yet).
  EMAIL_CONFIRMATION_BYTES           = 32
  EMAIL_CONFIRMATION_TTL             = 24.hours
  EMAIL_CONFIRMATION_RESEND_INTERVAL = 5.minutes

  # Password reset links. Short-lived because a letter can be forwarded; the
  # raw token exists only in the link, the database keeps a SHA-256 digest.
  PASSWORD_RESET_BYTES           = 32
  PASSWORD_RESET_TTL             = 1.hour
  PASSWORD_RESET_RESEND_INTERVAL = 5.minutes

  def self.ai_usage_rank(value : String) : Int32
    AI_USAGE_LEVELS.index(value) || 0
  end

  def self.valid_ai_usage?(value : String) : Bool
    AI_USAGE_LEVELS.includes?(value)
  end

  def self.email_confirmation_required? : Bool
    ENV["EMAIL_CONFIRMATION"]?.try(&.strip.downcase) != "off"
  end

  # Storage limits are read on demand so a deployment can tune them in
  # /etc/isho/api.env without a rebuild.
  def self.project_storage_limit : Int64
    env_bytes("STORAGE_PROJECT_LIMIT_BYTES", STORAGE_DEFAULT_PROJECT)
  end

  def self.account_storage_limit : Int64
    env_bytes("STORAGE_ACCOUNT_LIMIT_BYTES", STORAGE_DEFAULT_ACCOUNT)
  end

  def self.server_storage_limit : Int64
    env_bytes("STORAGE_SERVER_LIMIT_BYTES", STORAGE_DEFAULT_SERVER)
  end

  # Disk space that uploads are never allowed to consume: the OS, Postgres and
  # logs need room to breathe even when every quota is used up.
  def self.storage_reserve : Int64
    env_bytes("STORAGE_RESERVE_BYTES", STORAGE_DEFAULT_RESERVE)
  end

  private def self.env_bytes(name : String, default : Int64) : Int64
    value = ENV[name]?.try(&.strip)
    return default if value.nil? || value.empty?

    parsed = value.to_i64?
    parsed && parsed.positive? ? parsed : default
  end

  def self.mail_from : String
    value = ENV["MAIL_FROM"]?.try(&.strip)
    value.nil? || value.empty? ? "no-reply@isho.local" : value
  end

  # Where confirmation links point. In production Caddy serves the web app and
  # the API from one origin; in development the web app runs on port 3000.
  def self.public_origin : String
    origin = ENV["APP_ORIGIN"]?.try(&.split(',').first?.try(&.strip))
    origin = ENV["APP_DOMAIN"]?.try(&.strip) if origin.nil? || origin.empty?
    origin = "http://localhost:3000" if origin.nil? || origin.empty?
    origin.not_nil!.sub(/\/+\z/, "")
  end

  # The key is the switch: no key means no AI anywhere, so a fresh checkout and
  # a deployment without secrets behave exactly as before.
  def self.ai_enabled? : Bool
    return false if ENV["AI_ENABLED"]?.try(&.strip.downcase) == "off"
    !ai_api_key.empty?
  end

  def self.ai_api_key : String
    ENV["AI_API_KEY"]?.try(&.strip) || ""
  end

  def self.ai_base_url : String
    value = ENV["AI_BASE_URL"]?.try(&.strip)
    value = "https://api.deepseek.com" if value.nil? || value.empty?
    value.not_nil!.sub(/\/+\z/, "")
  end

  def self.ai_model : String
    value = ENV["AI_MODEL"]?.try(&.strip)
    value.nil? || value.empty? ? "deepseek-chat" : value
  end

  def self.ai_daily_jobs : Int32
    env_int("AI_DAILY_JOBS", AI_DEFAULT_DAILY_JOBS)
  end

  def self.ai_daily_input_tokens : Int64
    env_int64("AI_DAILY_INPUT_TOKENS", AI_DEFAULT_DAILY_INPUT_TOKENS)
  end

  def self.ai_daily_output_tokens : Int64
    env_int64("AI_DAILY_OUTPUT_TOKENS", AI_DEFAULT_DAILY_OUTPUT_TOKENS)
  end

  # Specs set this to zero so retries do not slow the suite down.
  def self.ai_retry_delay : Time::Span
    env_int("AI_RETRY_DELAY_MS", 2_000).milliseconds
  end

  def self.ai_answer_timeout : Time::Span
    env_int("AI_ANSWER_TIMEOUT_SECONDS", 90).seconds
  end

  def self.ai_quick_timeout : Time::Span
    env_int("AI_QUICK_TIMEOUT_SECONDS", 20).seconds
  end

  private def self.env_int(name : String, default : Int32) : Int32
    value = ENV[name]?.try(&.strip)
    return default if value.nil? || value.empty?

    parsed = value.to_i?
    parsed && parsed.positive? ? parsed : default
  end

  private def self.env_int64(name : String, default : Int64) : Int64
    value = ENV[name]?.try(&.strip)
    return default if value.nil? || value.empty?

    parsed = value.to_i64?
    parsed && parsed.positive? ? parsed : default
  end
end
