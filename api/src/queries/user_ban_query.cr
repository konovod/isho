class UserBanQuery < UserBan::BaseQuery
  def for_user(user_id : Int64)
    user_id(user_id)
  end

  def active
    lifted_at.is_nil.expires_at.gt(Time.utc)
  end

  def newest_first
    created_at.desc_order
  end
end
