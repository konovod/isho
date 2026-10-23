class AiUsageQuery < AiUsage::BaseQuery
  def for_user(user_id : Int64)
    user_id(user_id)
  end

  def of_kind(value : String)
    kind(value)
  end

  def on(day : Time)
    day(day)
  end
end
