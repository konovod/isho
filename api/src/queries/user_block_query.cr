class UserBlockQuery < UserBlock::BaseQuery
  def for_blocker(user_id : Int64)
    blocker_id(user_id)
  end

  def blocker(blocker_id : Int64)
    blocker_id(blocker_id)
  end

  def blocked_user(blocked_user_id : Int64)
    blocked_user_id(blocked_user_id)
  end

  def newest_first
    created_at.desc_order
  end
end
