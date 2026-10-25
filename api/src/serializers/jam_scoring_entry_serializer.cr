class JamScoringEntrySerializer < BaseSerializer
  def initialize(
    @entry : JamEntry,
    @my_scores : Array(JamScore),
    @complete : Bool,
  )
  end

  def render
    {
      entry:     JamEntrySerializer.new(@entry),
      complete:  @complete,
      my_scores: @my_scores.map do |score|
        {
          criterion_id: score.criterion_id,
          score:        score.score,
          comment:      score.comment,
        }
      end,
    }
  end
end
