class JamFeedbackSerializer < BaseSerializer
  def initialize(@feedback : JamFeedback::Result, @include_voter : Bool = false)
  end

  def render
    {
      entry_id: @feedback.entry.id,
      project:  {
        slug:  @feedback.entry.project.slug,
        title: @feedback.entry.project.title,
      },
      mode:          @feedback.mode,
      counted_votes: @feedback.counted_votes,
      total_votes:   @feedback.total_votes,
      criteria:      @feedback.criteria.map do |criterion|
        {
          id:      criterion.criterion.id,
          title:   criterion.criterion.title,
          weight:  criterion.criterion.weight,
          average: criterion.average.round(2),
          items:   criterion.items.map do |item|
            {
              score:   item.score.score,
              comment: item.score.comment,
              counted: item.counted,
              voter:   @include_voter ? UserSerializer.new(item.score.user) : nil,
            }
          end,
        }
      end,
    }
  end
end
