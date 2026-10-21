class Api::V1::Forum::Posts::Delete < ApiAction
  include Api::V1::Forum::Lookup
  include Api::V1::Forum::Authorization

  delete "/api/v1/forum/posts/:id" do
    post = find_forum_post!(params.get(:id))
    require_forum_moderator!

    first_post = ForumPostQuery.new
      .for_topic(post.topic_id)
      .chronological
      .first?

    if first_post.try(&.id) == post.id
      json ErrorSerializer.new(
        code: "first_post",
        message: "Нельзя удалить первое сообщение темы. Удалите тему целиком.",
      ), status: 422
    else
      DeleteForumPost.run!(post: post)
      head 204
    end
  end
end
