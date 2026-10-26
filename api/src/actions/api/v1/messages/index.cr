class Api::V1::Messages::Index < ApiAction
  get "/api/v1/messages" do
    entries = DirectMessages.inbox(current_user)
    context.response.headers["Cache-Control"] = "private, no-store"

    json({
      items:        entries.map { |entry| ConversationSerializer.new(entry) },
      unread_count: entries.sum(&.unread_count),
    })
  end
end
