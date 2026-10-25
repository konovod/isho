class RestoreJamEntry < Avram::Operation
  needs entry : JamEntry

  def run
    JamEntry::SaveOperation.update!(
      entry,
      status: "submitted",
      disqualified_reason: nil,
      disqualified_at: nil,
      disqualified_by_id: nil,
    )
  end
end
