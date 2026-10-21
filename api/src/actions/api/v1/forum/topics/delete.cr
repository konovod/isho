class Api::V1::Forum::Topics::Delete < ApiAction
  include Api::V1::Forum::Lookup
  include Api::V1::Forum::Authorization

  delete "/api/v1/forum/topics/:id" do
    topic = find_forum_topic!(params.get(:id))
    require_forum_moderator!

    DeleteForumTopic.run!(topic: topic)
    head 204
  end
end
