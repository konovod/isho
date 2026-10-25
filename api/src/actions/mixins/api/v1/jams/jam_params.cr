module Api::V1::Jams::JamParams
  memoize def jam : Jam
    JamQuery.new
      .slug(params.get(:slug))
      .preload_detail
      .first? || raise Avram::RecordNotFoundError.new(Jam.table_name, params.get(:slug).to_s)
  end

  # Drafts are visible only to their organizer and admins. A jam that was
  # published and later canceled stays available as a notice page.
  def jam_visible? : Bool
    user = current_user?
    return true if user && (jam.user_id == user.id || user.moderator?)

    jam.published? || (jam.canceled? && !jam.published_at.nil?)
  end

  def reload_jam(jam : Jam) : Jam
    JamQuery.new
      .id(jam.id)
      .preload_detail
      .first? || raise Avram::RecordNotFoundError.new(Jam.table_name, jam.id.to_s)
  end
end
