class Api::V1::Messages::Read < ApiAction
  include Api::V1::Messages::Lookup

  post "/api/v1/messages/:username/read" do
    peer = find_peer!(params.get(:username))
    require_other_user!(peer)

    MarkPrivateMessagesRead.run!(user: current_user, peer: peer)
    context.response.headers["Cache-Control"] = "private, no-store"

    json({unread_count: DirectMessages.unread_count(current_user)})
  end
end
