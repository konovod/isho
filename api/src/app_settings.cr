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
end
