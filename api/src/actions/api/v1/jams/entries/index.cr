class Api::V1::Jams::Entries::Index < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Jams::JamParams

  get "/api/v1/jams/:slug/entries" do
    unless jam_visible?
      raise Avram::RecordNotFoundError.new(Jam.table_name, params.get(:slug).to_s)
    end

    page = (params.get?(:page).try(&.to_i?) || 1).clamp(1, 10_000)
    per_page = (params.get?(:per_page).try(&.to_i?) || AppSettings::JAM_ENTRIES_PER_PAGE).clamp(1, 100)
    all = include_disqualified?

    query = JamEntryQuery.new.for_jam(jam.id).preload_card
    query = all ? query : query.submitted
    query = params.get?(:sort).try(&.downcase) == "oldest" ? query.oldest : query.newest

    entries = query.results
    entries = JamEntryVisibility.visible(entries, current_user?) unless all

    total = entries.size.to_i64
    items = entries[(page - 1) * per_page, per_page]? || [] of JamEntry

    json({
      items: items.map { |entry| JamEntrySerializer.new(entry) },
      meta:  {
        page:     page,
        per_page: per_page,
        total:    total,
        pages:    (total + per_page - 1) // per_page,
      },
    })
  end

  # The organizer and moderators may ask for disqualified entries; everybody
  # else always gets the public list.
  private def include_disqualified? : Bool
    return false unless params.get?(:status).try(&.downcase) == "all"

    user = current_user?
    !!user && (user.id == jam.user_id || user.moderator?)
  end
end
