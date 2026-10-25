class ProjectJamEntrySerializer < BaseSerializer
  def initialize(@entry : JamEntry)
  end

  def render
    jam = @entry.jam

    {
      id:                  @entry.id,
      status:              @entry.status,
      created_at:          @entry.created_at,
      disqualified_reason: @entry.disqualified_reason,
      jam:                 {
        id:                   jam.id,
        slug:                 jam.slug,
        title:                jam.title,
        phase:                JamPhase.key(jam),
        starts_at:            jam.starts_at,
        submissions_close_at: jam.submissions_close_at,
      },
    }
  end
end
