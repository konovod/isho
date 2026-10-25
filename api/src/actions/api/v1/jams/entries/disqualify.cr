class Api::V1::Jams::Entries::Disqualify < ApiAction
  include Api::V1::Jams::RequireOwner
  include Api::V1::Jams::EntryParams
  include Api::Auth::RequireConfirmedEmail

  post "/api/v1/jams/:slug/entries/:id/disqualify" do
    if entry.disqualified?
      return json ErrorSerializer.new(
        code: "already_disqualified",
        message: "Заявка уже снята",
      ), status: 422
    end

    fields = params.nested?("jam_entry")
    reason = fields["disqualified_reason"]?.to_s.strip

    if reason.nil? || reason.empty?
      return json ErrorSerializer.new(
        code: "validation_failed",
        message: "Укажите причину",
        details: {"disqualified_reason" => ["is required"]},
      ), status: 422
    end

    if reason.size > 500
      return json ErrorSerializer.new(
        code: "validation_failed",
        message: "Причина слишком длинная",
        details: {"disqualified_reason" => ["is too long"]},
      ), status: 422
    end

    DisqualifyJamEntry.run!(entry: entry, moderator: current_user, reason: reason)

    json JamEntrySerializer.new(reload_entry(entry))
  end
end
