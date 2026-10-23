module AppSettings
  SESSION_TTL           = 30.days
  SCREENSHOT_MAX_BYTES  = 10_000_000_i64
  SCREENSHOTS_PER_PAGE  =             24
  PROJECTS_PER_PAGE     =             24
  MAX_SCREENSHOTS       =             20
  MAX_DOWNLOADS         =             20
  MAX_EXTERNAL_URL_SIZE =           2048
  FORUM_TOPICS_PER_PAGE =             25
  FORUM_POSTS_PER_PAGE  =             20
  FORUM_POST_MAX_CHARS  =         20_000
  FORUM_QUOTE_MAX_CHARS =          2_000
  FORUM_TOPIC_TITLE_MAX =            160
  # Inline images in project descriptions, devlogs and forum posts. GIFs are
  # allowed as-is: ImageMagick keeps their frames and delays when resizing.
  MARKDOWN_IMAGE_MAX_BYTES = 10_000_000_i64
  MARKDOWN_IMAGE_TYPES     = %w[
    image/jpeg image/png image/webp image/gif
  ]
  THEMES = %w[light dark]

  # AI involvement, ordered from the least to the most. `max_ai_usage` on a
  # user is the highest level they want to see.
  AI_USAGE_LEVELS    = %w[ai_free partial significant full]
  RESERVED_USERNAMES = %w[
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
end
