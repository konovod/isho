class Api::V1::Jams::Entries::Restore < ApiAction
  include Api::V1::Jams::RequireOwner
  include Api::V1::Jams::EntryParams
  include Api::Auth::RequireConfirmedEmail

  post "/api/v1/jams/:slug/entries/:id/restore" do
    unless entry.disqualified?
      return json ErrorSerializer.new(
        code: "entry_not_disqualified",
        message: "Заявка не снята",
      ), status: 422
    end

    RestoreJamEntry.run!(entry: entry)

    json JamEntrySerializer.new(reload_entry(entry))
  end
end
