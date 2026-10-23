class Api::V1::Forum::TopicSuggestions::Create < ApiAction
  include Api::V1::Forum::Params
  include Api::Auth::RequireConfirmedEmail
  include Api::Auth::RequireNotBanned
  include Lucky::RateLimit
  rate_limit to: 10, within: 1.hour

  post "/api/v1/forum/topic_suggestions" do
    fields = forum_topic_fields
    section_slug = fields["section_slug"]? || ""

    section = ForumSectionQuery.new.by_slug(section_slug).first?
    suggestion = section.try do |current|
      Ai::Suggest.call(
        current_user,
        current,
        fields["title"]? || "",
        fields["body"]? || "",
      )
    end

    json({suggestion: suggestion.try { |value| TopicSuggestionSerializer.new(value) }})
  end

  private def rate_limit_identifier : String
    "ai-topic-suggestion:#{current_user.id}"
  end
end
