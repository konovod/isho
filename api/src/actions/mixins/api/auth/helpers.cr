module Api::Auth::Helpers
  SESSION_COOKIE = "isho_auth"

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
    cookies.set_raw(SESSION_COOKIE, token).expires(AppSettings::SESSION_TTL.from_now)
  end

  def sign_out : Nil
    if token = session_token
      ::Auth::Session.destroy(token)
    end
    cookies.delete(SESSION_COOKIE)
  end

  private def session_token : String?
    cookies.get_raw?(SESSION_COOKIE).try(&.value)
  end
end
