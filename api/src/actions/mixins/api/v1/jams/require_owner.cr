module Api::V1::Jams::RequireOwner
  macro included
    include Api::V1::Jams::JamParams

    before require_jam_owner

    # Registered after the ownership check: a stranger gets 404 instead of a
    # hint that a draft exists.
    include Api::Auth::RequireNotBanned
  end

  private def require_jam_owner
    unless jam.user_id == current_user.id || current_user.moderator?
      raise Avram::RecordNotFoundError.new(Jam.table_name, params.get(:slug).to_s)
    end

    continue
  end
end
