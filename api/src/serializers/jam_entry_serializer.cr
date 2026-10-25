class JamEntrySerializer < BaseSerializer
  def initialize(@entry : JamEntry)
  end

  def render
    {
      id:                  @entry.id,
      status:              @entry.status,
      created_at:          @entry.created_at,
      disqualified_reason: @entry.disqualified_reason,
      disqualified_at:     @entry.disqualified_at,
      project:             ProjectSerializer.new(@entry.project),
    }
  end
end
