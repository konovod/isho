class Api::V1::Me::BlockedUsers::Index < ApiAction
  get "/api/v1/me/blocked_users" do
    blocks = UserBlockQuery.new
      .for_blocker(current_user.id)
      .newest_first
      .preload_blocked_user
      .results

    json({items: blocks.map { |block| BlockedUserSerializer.new(block) }})
  end
end
