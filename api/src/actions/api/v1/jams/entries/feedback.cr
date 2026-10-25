class Api::V1::Jams::Entries::Feedback < ApiAction
  include Api::V1::Jams::JamParams
  include Api::V1::Jams::EntryParams

  get "/api/v1/jams/:slug/entries/:id/feedback" do
    organizer = current_user.id == jam.user_id || current_user.moderator?
    author = current_user.id == entry.user_id

    unless organizer || author
      raise Avram::RecordNotFoundError.new(JamEntry.table_name, params.get(:id).to_s)
    end

    unless organizer || JamPhase.results_visible?(jam)
      return json ErrorSerializer.new(
        code: "feedback_not_ready",
        message: "Отзывы откроются после окончания судейства",
      ), status: 422
    end

    feedback = JamFeedback.for(jam, entry)

    json JamFeedbackSerializer.new(feedback, include_voter: organizer)
  end
end
