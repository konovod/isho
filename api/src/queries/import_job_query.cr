class ImportJobQuery < ImportJob::BaseQuery
  def queued
    status("queued")
  end

  def running
    status("running")
  end

  def active
    status.in(["queued", "running"])
  end

  def due(now = Time.utc)
    run_after.lte(now)
  end

  def for_user(owner_id : Int64)
    user_id(owner_id)
  end

  def oldest_first
    created_at.asc_order
  end

  def recent_first
    created_at.desc_order
  end
end
