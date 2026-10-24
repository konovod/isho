module Api::Auth::Helpers
  SESSION_COOKIE              = "isho_auth"
  SECURE_SESSION_COOKIE       = "__Host-#{SESSION_COOKIE}"
  IMPERSONATION_COOKIE        = "isho_act_as"
  SECURE_IMPERSONATION_COOKIE = "__Host-#{IMPERSONATION_COOKIE}"

  # The `__Host-` prefix ties the cookie to the exact host: the browser refuses
  # to store it with a Domain attribute, so a page on a sibling host (browser
  # builds live on their own origin) cannot shadow the session with a
  # parent-domain cookie. Browsers accept that prefix only with Secure, so
  # plain-HTTP development keeps the plain name.
  def self.cookie_name : String
    AppSettings.secure_cookies? ? SECURE_SESSION_COOKIE : SESSION_COOKIE
  end

  # The second cookie keeps the admin signed in while they view the site as
  # somebody else, so returning is just dropping this cookie.
  def self.impersonation_cookie_name : String
    AppSettings.secure_cookies? ? SECURE_IMPERSONATION_COOKIE : IMPERSONATION_COOKIE
  end

  # The current user, looked up from the opaque session cookie. While an admin
  # impersonates somebody, this is the target account on purpose: the site must
  # behave exactly as that person sees it.
  memoize def current_user? : User?
    imp = impersonation
    imp ? imp.user : session_user
  end

  # The real signed-in account behind the impersonation, if any.
  memoize def impersonation : ::Auth::Impersonation?
    admin = session_user
    return nil unless admin

    token = impersonation_token
    return nil if token.nil? || token.empty?

    session = ::Auth::Session.impersonation_for(token, admin.id)
    return nil unless session

    ::Auth::Impersonation.new(session, admin, session.user)
  end

  # The account from the main cookie, ignoring any impersonation.
  memoize def session_user : User?
    token = session_token
    token ? ::Auth::Session.user_for(token) : nil
  end

  def sign_in(user : User) : Nil
    # A fresh sign-in must not revive an old view of another account.
    clear_impersonation
    _, token = ::Auth::Session.start(
      user,
      user_agent: context.request.headers["User-Agent"]?,
    )
    cookies.set_raw(cookie_name, token).expires(AppSettings::SESSION_TTL.from_now)
  end

  # Ends the view of another account and returns the admin behind it while
  # their own session is still alive.
  def stop_impersonation : User?
    admin = session_user
    clear_impersonation
    admin
  end

  # Creates the short target session. The admin cookie is left untouched.
  def start_impersonation(user : User) : ::Auth::Impersonation
    admin = current_user
    clear_impersonation

    session, token = ::Auth::Session.start(
      user,
      user_agent: context.request.headers["User-Agent"]?,
      ip: context.request.remote_ip,
      ttl: AppSettings::IMPERSONATION_TTL,
      impersonator_id: admin.id,
    )
    cookies.set_raw(impersonation_cookie_name, token).expires(AppSettings::IMPERSONATION_TTL.from_now)

    ::Auth::Impersonation.new(session, admin, user)
  end

  def sign_out : Nil
    clear_impersonation
    if token = session_token
      ::Auth::Session.destroy(token)
    end
    cookies.delete(cookie_name)
  end

  private def clear_impersonation : Nil
    if token = impersonation_token
      ::Auth::Session.destroy(token)
    end
    cookies.delete(impersonation_cookie_name)
  end

  private def cookie_name : String
    Api::Auth::Helpers.cookie_name
  end

  private def impersonation_cookie_name : String
    Api::Auth::Helpers.impersonation_cookie_name
  end

  private def session_token : String?
    cookies.get_raw?(cookie_name).try(&.value)
  end

  private def impersonation_token : String?
    cookies.get_raw?(impersonation_cookie_name).try(&.value)
  end
end
