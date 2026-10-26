class Api::V1::Users::Blocks::Create < ApiAction
  include Api::V1::Users::Lookup

  post "/api/v1/users/:username/block" do
    user = find_user!(params.get(:username))

    if user.id == current_user.id
      return json(ErrorSerializer.new(
        code: "cannot_block_self",
        message: "Нельзя заблокировать свой аккаунт.",
      ), status: 422)
    end

    unless UserBlockQuery.new.blocker(current_user.id).blocked_user(user.id).first?
      AppDatabase.transaction do
        BlockUser.create!(
          blocker_id: current_user.id,
          blocked_user_id: user.id,
        )

        # The blocker should not keep a badge for messages that are about to
        # disappear from their view.
        MarkPrivateMessagesRead.run!(user: current_user, peer: user)
      end
    end

    json({
      blocked:               true,
      unread_messages_count: DirectMessages.unread_count(current_user),
    })
  end
end
