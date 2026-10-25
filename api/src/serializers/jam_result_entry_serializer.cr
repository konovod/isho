class JamResultEntrySerializer < BaseSerializer
  def initialize(@result : JamResults::EntryResult)
  end

  def render
    {
      entry_id:    @result.entry.id,
      place:       @result.place,
      total:       @result.total.round(2),
      max_total:   @result.max_total,
      votes_count: @result.votes_count,
      project:     ProjectSerializer.new(@result.entry.project),
      criteria:    @result.criteria.map do |criterion|
        {
          criterion_id: criterion.criterion.id,
          title:        criterion.criterion.title,
          weight:       criterion.criterion.weight,
          average:      criterion.average.round(2),
        }
      end,
    }
  end
end
