module Api::Auth::Helpers
  SESSION_COOKIE        = "isho_auth"
  SECURE_SESSION_COOKIE = "__Host-#{SESSION_COOKIE}"

  # The `__Host-` prefix ties the cookie to the exact host: the browser refuses
  # to store it with a Domain attribute, so a page on a sibling host (browser
  # builds live on their own origin) cannot shadow the session with a
  # parent-domain cookie. Browsers accept that prefix only with Secure, so
  # plain-HTTP development keeps the plain name.
  def self.cookie_name : String
    AppSettings.secure_cookies? ? SECURE_SESSION_COOKIE : SESSION_COOKIE
  end

  # The current user, looked up from the opaque session cookie.
  memoize def current_user? : User?
    token = session_token
    token ? ::Auth::Session.user_for(token) : nil
  end

  def sign_in(user : User) : Nil
    _, token = ::Auth::Session.start(
      user,
      user_agent: context.request.headers["User-Agent"]?,
    )
    cookies.set_raw(cookie_name, token).expires(AppSettings::SESSION_TTL.from_now)
  end

  def sign_out : Nil
    if token = session_token
      ::Auth::Session.destroy(token)
    end
    cookies.delete(cookie_name)
  end

  private def cookie_name : String
    Api::Auth::Helpers.cookie_name
  end

  private def session_token : String?
    cookies.get_raw?(cookie_name).try(&.value)
  end
end
