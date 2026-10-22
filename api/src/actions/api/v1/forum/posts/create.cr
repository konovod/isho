class Api::V1::Forum::Posts::Create < ApiAction
  include Api::V1::Forum::Params
  include Api::V1::Forum::Lookup
  include Api::V1::Forum::Visibility
  include Api::Auth::RequireConfirmedEmail

  post "/api/v1/forum/topics/:id/posts" do
    topic = find_forum_topic!(params.get(:id))
    require_visible_forum_topic!(topic)

    fields = forum_post_fields
    quote_id = fields["quoted_post_id"]?.try(&.to_i64?)

    post = CreateForumPost.run!(
      topic: topic,
      user: current_user,
      body: fields["body"]? || "",
      quoted_post_id: quote_id,
      quote_text: fields["quote_text"]?,
    )

    json ForumPostSerializer.new(reload_forum_post(post), forum_quote_page(post)), status: 201
  end
end
