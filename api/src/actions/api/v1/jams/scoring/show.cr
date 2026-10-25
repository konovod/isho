class Api::V1::Jams::Scoring::Show < ApiAction
  include Api::V1::Jams::JamParams
  include Api::Auth::RequireConfirmedEmail
  include Api::Auth::RequireNotBanned

  get "/api/v1/jams/:slug/scoring" do
    unless jam_visible?
      raise Avram::RecordNotFoundError.new(Jam.table_name, params.get(:slug).to_s)
    end

    unless JamPhase.accepts_scores?(jam)
      return json ErrorSerializer.new(
        code: "judging_closed",
        message: "Судейство ещё не началось или уже закончилось",
      ), status: 422
    end

    criteria = jam.criteria.sort_by(&.position)
    criterion_ids = criteria.map(&.id)

    entries = JamEntryQuery.new
      .for_jam(jam.id)
      .submitted
      .preload_card
      .newest
      .results
      .select { |entry| entry.user_id != current_user.id }

    unless current_user.id == jam.user_id || current_user.moderator?
      entries = JamEntryVisibility.visible(entries, current_user)
    end

    my_scores = entries.empty? ? [] of JamScore : JamScoreQuery.new
      .for_entries(entries.map(&.id))
      .for_user(current_user.id)
      .results
    scores_by_entry = my_scores.group_by(&.entry_id)

    scored = 0
    items = entries.map do |entry|
      scores = scores_by_entry[entry.id]? || [] of JamScore
      complete = criterion_ids.all? { |id| scores.any? { |score| score.criterion_id == id } }
      scored += 1 if complete

      JamScoringEntrySerializer.new(entry, scores, complete)
    end

    json({
      jam:      JamSerializer.new(jam, current_user?, detailed: true),
      items:    items,
      progress: {scored: scored, total: entries.size},
    })
  end
end
