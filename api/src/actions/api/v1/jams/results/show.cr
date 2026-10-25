class Api::V1::Jams::Results::Show < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Jams::JamParams

  get "/api/v1/jams/:slug/results" do
    unless jam_visible?
      raise Avram::RecordNotFoundError.new(Jam.table_name, params.get(:slug).to_s)
    end

    user = current_user?
    organizer = !!user && (user.id == jam.user_id || user.moderator?)
    preview = organizer && params.get?(:preview).try(&.downcase) == "true"
    available = JamPhase.results_visible?(jam) || preview

    results = available ? JamResults.for(jam, user, preview: preview) : [] of JamResults::EntryResult

    json JamResultsSerializer.new(jam, results, available)
  end
end
