module Api::V1::Jams::EntryParams
  memoize def entry : JamEntry
    JamEntryQuery.new
      .for_jam(jam.id)
      .id(params.get(:id))
      .preload_card
      .first? || raise Avram::RecordNotFoundError.new(JamEntry.table_name, params.get(:id).to_s)
  end

  def reload_entry(entry : JamEntry) : JamEntry
    JamEntryQuery.new
      .id(entry.id)
      .preload_card
      .first? || raise Avram::RecordNotFoundError.new(JamEntry.table_name, entry.id.to_s)
  end
end
