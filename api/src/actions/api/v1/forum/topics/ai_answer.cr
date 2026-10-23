class Api::V1::Forum::Topics::AiAnswer < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Forum::Lookup
  include Api::V1::Forum::Visibility

  # The topic page polls this while the answer is queued.
  get "/api/v1/forum/topics/:id/ai_answer" do
    topic = find_forum_topic!(params.get(:id))
    require_visible_forum_topic!(topic)

    answer = ForumAiAnswerQuery.new.for_topic(topic.id).first?
    json({ai_answer: answer.try { |value| ForumAiAnswerSerializer.new(value) }})
  end
end
