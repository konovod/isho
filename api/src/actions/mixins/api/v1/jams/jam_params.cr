module Api::V1::Jams::JamParams
  memoize def jam : Jam
    JamQuery.new
      .slug(params.get(:slug))
      .preload_detail
      .first? || raise Avram::RecordNotFoundError.new(Jam.table_name, params.get(:slug).to_s)
  end

  # Drafts and canceled jams are visible only to their organizer and admins.
  def jam_visible? : Bool
    user = current_user?
    return true if user && (jam.user_id == user.id || user.moderator?)

    jam.published? && !jam.canceled?
  end

  def reload_jam(jam : Jam) : Jam
    JamQuery.new
      .id(jam.id)
      .preload_detail
      .first? || raise Avram::RecordNotFoundError.new(Jam.table_name, jam.id.to_s)
  end
end
