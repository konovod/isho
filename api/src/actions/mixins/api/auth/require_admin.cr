module Api::Auth::RequireAdmin
  macro included
    before require_admin
  end

  private def require_admin
    if current_user.moderator?
      continue
    else
      raise Api::ForbiddenError.new
    end
  end
end
