class Api::V1::Users::Blocks::Delete < ApiAction
  include Api::V1::Users::Lookup

  delete "/api/v1/users/:username/block" do
    user = find_user!(params.get(:username))

    if block = UserBlockQuery.new.blocker(current_user.id).blocked_user(user.id).first?
      UserBlock::DeleteOperation.delete!(block)
    end

    json({
      blocked:               false,
      unread_messages_count: DirectMessages.unread_count(current_user),
    })
  end
end
