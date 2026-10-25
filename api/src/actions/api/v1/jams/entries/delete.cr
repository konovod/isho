class Api::V1::Jams::Entries::Delete < ApiAction
  include Api::V1::Jams::JamParams
  include Api::V1::Jams::EntryParams

  delete "/api/v1/jams/:slug/entries/:id" do
    owner = current_user.id == entry.user_id
    organizer = current_user.id == jam.user_id || current_user.moderator?

    unless owner || organizer
      raise Avram::RecordNotFoundError.new(JamEntry.table_name, params.get(:id).to_s)
    end

    # The author can withdraw while submissions are open. After the deadline
    # only the organizer removes an entry, so results cannot be changed quietly.
    if owner && !organizer && !JamPhase.accepts_entries?(jam)
      return json ErrorSerializer.new(
        code: "entry_locked",
        message: "Приём заявок закрыт — отозвать заявку может только организатор",
      ), status: 422
    end

    JamEntry::DeleteOperation.delete!(entry)
    head 204
  end
end
