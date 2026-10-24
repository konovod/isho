class AuthSession < BaseModel
  table do
    belongs_to user : User
    column token_hash : String
    column expires_at : Time
    column user_agent : String?
    column ip : String?
    # Set on the short session an admin opens to view the site as another
    # account. It only works next to the admin's own session cookie.
    column impersonator_id : Int64?
  end

  def expired? : Bool
    expires_at <= Time.utc
  end
end
