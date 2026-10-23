class AiJobQuery < AiJob::BaseQuery
  def queued
    status("queued")
  end

  def running
    status("running")
  end

  def due(now = Time.utc)
    run_after.lte(now)
  end

  def of_kind(value : String)
    kind(value)
  end

  def oldest_first
    created_at.asc_order
  end

  def recent_first
    created_at.desc_order
  end
end
