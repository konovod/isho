class Api::V1::Forum::Posts::Reactions::Toggle < ApiAction
  include Api::V1::Forum::Params
  include Api::V1::Forum::Lookup
  include Api::V1::Forum::Visibility
  include Api::Auth::RequireNotBanned

  post "/api/v1/forum/posts/:id/reactions" do
    post = find_forum_post!(params.get(:id))
    require_visible_forum_topic!(post.topic)
    require_visible_forum_post!(post)

    if post.user_id == current_user.id
      return json(ErrorSerializer.new(
        code: "own_post",
        message: "Нельзя голосовать за своё сообщение.",
      ), status: 422)
    end

    kind = forum_post_reaction_fields["kind"]?.to_s.strip
    unless ForumPostReaction.valid_kind?(kind)
      return json(ErrorSerializer.new(
        code: "validation_failed",
        message: "Неизвестный тип реакции.",
        details: {"kind" => ["is invalid"]},
      ), status: 422)
    end

    # One endpoint for both directions: a missing vote is added, the same one
    # is removed and the opposite one replaces it.
    ToggleForumPostReaction.run!(post: post, user: current_user, kind: kind)

    json({reactions: ForumPostReactionsSerializer.new(ForumReactions.summary(post.id, current_user.id)).render})
  end
end
