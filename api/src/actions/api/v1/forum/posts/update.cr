class Api::V1::Forum::Posts::Update < ApiAction
  include Api::V1::Forum::Lookup
  include Api::V1::Forum::Authorization
  include Api::V1::Forum::Visibility
  include Api::Auth::RequireNotBanned

  patch "/api/v1/forum/posts/:id" do
    post = find_forum_post!(params.get(:id))
    require_visible_forum_topic!(post.topic)
    require_forum_editor!(post.user_id)

    updated = SaveForumPost.update!(post, params)
    json ForumPostSerializer.new(
      reload_forum_post(updated),
      forum_quote_page(updated),
      ForumReactions.summary(updated.id, current_user?.try(&.id)),
    )
  end
end
