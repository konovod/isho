class JamResultsSerializer < BaseSerializer
  def initialize(
    @jam : Jam,
    @results : Array(JamResults::EntryResult),
    @available : Bool,
  )
  end

  def render
    {
      available: @available,
      jam:       {
        slug:             @jam.slug,
        title:            @jam.title,
        phase:            JamPhase.key(@jam),
        judging_mode:     @jam.judging_mode,
        score_scale:      @jam.score_scale,
        results_note:     @jam.results_note,
        voting_closes_at: @jam.voting_closes_at,
        time_zone:        @jam.time_zone,
      },
      items: @available ? @results.map { |result| JamResultEntrySerializer.new(result) } : [] of JamResultEntrySerializer,
    }
  end
end
