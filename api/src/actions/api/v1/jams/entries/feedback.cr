class Api::V1::Jams::Entries::Feedback < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Jams::JamParams
  include Api::V1::Jams::EntryParams

  get "/api/v1/jams/:slug/entries/:id/feedback" do
    unless jam_visible?
      raise Avram::RecordNotFoundError.new(Jam.table_name, params.get(:slug).to_s)
    end

    viewer = current_user?
    organizer = !!viewer && (viewer.id == jam.user_id || viewer.moderator?)
    author = !!viewer && viewer.id == entry.user_id
    finished = JamPhase.results_visible?(jam)

    unless organizer || finished
      return json ErrorSerializer.new(
        code: "feedback_not_ready",
        message: "Отзывы откроются после окончания судейства",
      ), status: 422
    end

    # Public feedback follows the same visibility as the entry itself. The
    # author keeps access to their own feedback even if the entry was removed
    # from the public list.
    unless organizer || author || (entry.submitted? && JamEntryVisibility.visible?(entry, viewer))
      raise Avram::RecordNotFoundError.new(JamEntry.table_name, params.get(:id).to_s)
    end

    feedback = JamFeedback.for(jam, entry)

    json JamFeedbackSerializer.new(feedback, include_voter: organizer)
  end
end
