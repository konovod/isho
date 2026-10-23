class UploadSessionQuery < UploadSession::BaseQuery
  def for_user(owner_id : Int64)
    user_id(owner_id)
  end

  def older_than(cutoff : Time)
    created_at.lt(cutoff)
  end
end
