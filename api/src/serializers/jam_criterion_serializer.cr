class JamCriterionSerializer < BaseSerializer
  def initialize(@criterion : JamCriterion)
  end

  def render
    {
      id:          @criterion.id,
      title:       @criterion.title,
      description: @criterion.description,
      weight:      @criterion.weight,
      position:    @criterion.position,
    }
  end
end
