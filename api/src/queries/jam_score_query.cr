class JamScoreQuery < JamScore::BaseQuery
  def for_entry(entry_id : Int64)
    entry_id(entry_id)
  end

  def for_entries(entry_ids : Array(Int64))
    entry_id.in(entry_ids)
  end

  def for_user(user_id : Int64)
    user_id(user_id)
  end

  def for_criterion(criterion_id : Int64)
    criterion_id(criterion_id)
  end

  def newest
    created_at.desc_order.id.desc_order
  end
end
