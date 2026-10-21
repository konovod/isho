module Api::Auth::RequireSession
  macro included
    before require_session
  end

  private def require_session
    if current_user?
      continue
    else
      json ErrorSerializer.new(
        code: "unauthorized",
        message: "Authentication required",
      ), status: 401
    end
  end

  # Tells the compiler that current_user is not nil after require_session.
  private def current_user : User
    current_user?.as(User)
  end
end
