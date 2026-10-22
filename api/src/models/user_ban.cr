class UserBan < BaseModel
  table do
    belongs_to user : User
    belongs_to banned_by : User?
    belongs_to lifted_by : User?
    column reason : String
    column expires_at : Time
    column lifted_at : Time?
  end

  def active? : Bool
    lifted_at.nil? && expires_at > Time.utc
  end

  def lifted? : Bool
    !lifted_at.nil?
  end

  def expired? : Bool
    expires_at <= Time.utc
  end

  def days_left : Int32
    remaining = expires_at - Time.utc
    (remaining.total_seconds / 86_400.0).ceil.to_i32.clamp(1, Int32::MAX)
  end
end
