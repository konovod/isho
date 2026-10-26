class Api::V1::Messages::Show < ApiAction
  include Api::V1::Messages::Lookup

  get "/api/v1/messages/:username" do
    peer = find_peer!(params.get(:username))
    require_other_user!(peer)

    per_page = AppSettings::PRIVATE_MESSAGES_PER_PAGE
    query = PrivateMessageQuery.new
      .between(current_user.id, peer.id)
      .visible_to(current_user.id)
    messages, has_more = conversation_page(query, per_page)
    context.response.headers["Cache-Control"] = "private, no-store"

    blocked = !UserBlockQuery.new.blocker(current_user.id).blocked_user(peer.id).first?.nil?

    json({
      peer:         UserSerializer.new(peer),
      items:        messages.map { |message| PrivateMessageSerializer.new(message, current_user.id) },
      has_more:     has_more,
      unread_count: DirectMessages.unread_count(current_user),
      blocked:      blocked,
    })
  end

  # Without a cursor the newest page is returned; `before` walks into the
  # history and `after` is what the «Обновить» button asks for.
  private def conversation_page(query : PrivateMessageQuery, per_page : Int32) : {Array(PrivateMessage), Bool}
    if after = params.get?(:after).try(&.to_i64?)
      messages = query
        .newer_than(after)
        .chronological
        .limit(AppSettings::PRIVATE_MESSAGES_REFRESH)
        .preload_sender
        .results

      return {messages, false}
    end

    if before = params.get?(:before).try(&.to_i64?)
      query = query.older_than(before)
    end

    rows = query.newest_first.limit(per_page + 1).preload_sender.results
    has_more = rows.size > per_page

    {rows.first(per_page).reverse, has_more}
  end
end
