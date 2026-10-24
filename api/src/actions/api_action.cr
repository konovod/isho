# Include modules and add methods that are for all API requests
abstract class ApiAction < Lucky::Action
  accepted_formats [:json]

  include Api::Auth::Helpers
  include Api::Auth::RequireSession
  include Lucky::EnforceUnderscoredRoute

  before ensure_same_origin

  # Impersonation is a read-only view: it must not change the target account.
  # The few actions that only end the view opt out with `allow_impersonation_writes?`.
  def self.allow_impersonation_writes? : Bool
    false
  end

  before ensure_impersonation_is_read_only

  # Cookie-based sessions are protected by SameSite=Lax. The Origin check
  # covers older browsers and any request that manages to attach a cookie.
  private def ensure_same_origin
    origin = context.request.headers["Origin"]?

    if origin && !%w[GET HEAD OPTIONS].includes?(context.request.method)
      unless allowed_origins.includes?(origin)
        raise Api::ForbiddenError.new
      end
    end

    continue
  end

  private def ensure_impersonation_is_read_only
    if impersonation &&
       !%w[GET HEAD OPTIONS].includes?(context.request.method) &&
       !self.class.allow_impersonation_writes?
      json ErrorSerializer.new(
        code: "impersonation_read_only",
        message: "В режиме просмотра изменения недоступны",
      ), status: 403
    else
      continue
    end
  end

  private def allowed_origins : Array(String)
    (ENV["APP_ORIGIN"]? || "http://localhost:3000,http://127.0.0.1:3000")
      .split(',')
      .map(&.strip)
      .reject(&.empty?)
  end
end
