class Api::V1::Forum::Topics::DeleteAiAnswer < ApiAction
  include Api::Auth::RequireAdmin
  include Api::V1::Forum::Lookup

  delete "/api/v1/forum/topics/:id/ai_answer" do
    topic = find_forum_topic!(params.get(:id))
    answer = ForumAiAnswerQuery.new.for_topic(topic.id).first?

    DeleteForumAiAnswer.run!(answer: answer) if answer
    head 204
  end
end
