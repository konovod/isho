class AuthSessionQuery < AuthSession::BaseQuery
  def active
    expires_at.gt(Time.utc)
  end
end
