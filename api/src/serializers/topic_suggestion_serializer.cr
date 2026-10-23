class TopicSuggestionSerializer < BaseSerializer
  def initialize(@suggestion : Ai::Suggest::Suggestion)
  end

  def render
    section = @suggestion.section

    {
      section:    {id: section.id, slug: section.slug, title: section.title},
      confidence: @suggestion.confidence,
      reason:     @suggestion.reason,
    }
  end
end
