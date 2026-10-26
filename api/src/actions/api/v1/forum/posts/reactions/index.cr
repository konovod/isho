class Api::V1::Forum::Posts::Reactions::Index < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Forum::Lookup
  include Api::V1::Forum::Visibility

  MAX_VOTERS = 10

  # Latest voters for the popup next to a counter.
  get "/api/v1/forum/posts/:id/reactions" do
    post = find_forum_post!(params.get(:id))
    require_visible_forum_topic!(post.topic)
    require_visible_forum_post!(post)

    kind = params.get?(:kind).try(&.strip).presence || ForumPostReaction::LIKE
    unless ForumPostReaction.valid_kind?(kind)
      return json(ErrorSerializer.new(
        code: "validation_failed",
        message: "Неизвестный тип реакции.",
        details: {"kind" => ["is invalid"]},
      ), status: 422)
    end

    query = ForumPostReactionQuery.new.for_post(post.id).by_kind(kind).newest_first
    total = query.clone.select_count
    voters = query.preload_user.limit(MAX_VOTERS).results.map(&.user)

    json({
      kind:      kind,
      total:     total,
      items:     voters.map { |user| UserSerializer.new(user) },
      truncated: total > MAX_VOTERS,
    })
  end
end
