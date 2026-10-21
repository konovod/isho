module AppSettings
  SESSION_TTL           = 30.days
  SCREENSHOT_MAX_BYTES  = 10_000_000_i64
  SCREENSHOTS_PER_PAGE  =             24
  PROJECTS_PER_PAGE     =             24
  MAX_SCREENSHOTS       =             20
  MAX_DOWNLOADS         =             20
  MAX_EXTERNAL_URL_SIZE =           2048
  RESERVED_USERNAMES    = %w[
    admin api dashboard login logout me new settings sign_in sign_up
    projects users assets articles jams forum support help about terms privacy
  ]
end
