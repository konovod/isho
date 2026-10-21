module Api::Auth::SkipRequireSession
  macro included
    skip require_session
  end

  # Public actions may still read the current user when a session exists.
  def current_user : User?
    current_user?
  end
end
