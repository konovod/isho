class DisqualifyJamEntry < Avram::Operation
  needs entry : JamEntry
  needs moderator : User
  needs reason : String

  def run
    JamEntry::SaveOperation.update!(
      entry,
      status: "disqualified",
      disqualified_reason: reason,
      disqualified_at: Time.utc,
      disqualified_by_id: moderator.id,
    )
  end
end
