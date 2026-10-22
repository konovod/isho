# Blocks creating and changing content while a ban is active. Reading, sign-in,
# theme and profile settings stay available.
module Api::Auth::RequireNotBanned
  macro included
    before require_not_banned
  end

  private def require_not_banned
    if current_user.banned?
      raise Api::UserBannedError.new
    else
      continue
    end
  end
end
