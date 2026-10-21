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
  THEMES                = %w[light dark]
  RESERVED_USERNAMES    = %w[
    admin api dashboard login logout me new settings sign_in sign_up
    projects users assets articles jams forum support help about terms privacy
  ]

  # Email confirmation. `EMAIL_CONFIRMATION=off` turns the requirement off
  # (useful locally and while a mail transport is not configured yet).
  EMAIL_CONFIRMATION_BYTES           = 32
  EMAIL_CONFIRMATION_TTL             = 24.hours
  EMAIL_CONFIRMATION_RESEND_INTERVAL = 5.minutes

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
