class Api::V1::Messages::Create < ApiAction
  include Api::Auth::RequireConfirmedEmail
  include Api::Auth::RequireNotBanned
  include Api::V1::Messages::Lookup
  include Api::V1::Messages::RateLimit

  post "/api/v1/messages/:username" do
    peer = find_peer!(params.get(:username))

    if peer.id == current_user.id
      return json(ErrorSerializer.new(
        code: "cannot_message_self",
        message: "Нельзя переписываться с самим собой.",
      ), status: 422)
    end

    fields = params.nested?("private_message")

    message = SavePrivateMessage.create!(
      sender_id: current_user.id,
      recipient_id: peer.id,
      body: fields["body"]? || "",
    )

    saved = PrivateMessageQuery.new.id(message.id).preload_sender.first? ||
            raise Avram::RecordNotFoundError.new(PrivateMessage.table_name, message.id.to_s)
    context.response.headers["Cache-Control"] = "private, no-store"

    json PrivateMessageSerializer.new(saved, current_user.id), status: 201
  end
end
