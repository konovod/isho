class Api::V1::Forum::Topics::Update < ApiAction
  include Api::V1::Forum::Lookup
  include Api::V1::Forum::Authorization
  include Api::V1::Forum::Visibility

  patch "/api/v1/forum/topics/:id" do
    topic = find_forum_topic!(params.get(:id))
    require_visible_forum_topic!(topic) unless current_user.moderator?
    require_forum_editor!(topic.user_id)

    updated = SaveForumTopic.update!(topic, params)
    json ForumTopicSerializer.new(reload_forum_topic(updated))
  end
end
