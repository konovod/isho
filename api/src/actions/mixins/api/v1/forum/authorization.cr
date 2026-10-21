module Api::V1::Forum::Authorization
  def forum_moderator? : Bool
    current_user?.try(&.moderator?) || false
  end

  def require_forum_moderator! : Nil
    raise Api::ForbiddenError.new unless forum_moderator?
  end

  def require_forum_editor!(user_id : Int64) : Nil
    user = current_user?
    allowed = user && (user.id == user_id || user.moderator?)
    raise Api::ForbiddenError.new unless allowed
  end
end
