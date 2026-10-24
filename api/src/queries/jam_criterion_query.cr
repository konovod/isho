class JamCriterionQuery < JamCriterion::BaseQuery
  def for_jam(jam_id : Int64)
    jam_id(jam_id)
  end

  def ordered
    position.asc_order.id.asc_order
  end
end
