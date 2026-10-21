class AuthSession < BaseModel
  table do
    belongs_to user : User
    column token_hash : String
    column expires_at : Time
    column user_agent : String?
    column ip : String?
  end

  def expired? : Bool
    expires_at <= Time.utc
  end
end
