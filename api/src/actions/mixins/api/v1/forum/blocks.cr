# The signed-in viewer's blacklist, loaded once per request. Forum pages use
# it to hide topics and messages of blocked accounts and to keep their
# activity out of unread counters.
module Api::V1::Forum::Blocks
  @forum_blocks : Array(UserBlock)?
  @forum_blocked_ids : Array(Int64)?
  @forum_blocked_usernames : Array(String)?

  def forum_blocks : Array(UserBlock)
    @forum_blocks ||= current_user?.try { |user|
      UserBlockQuery.new.for_blocker(user.id).preload_blocked_user.results
    } || [] of UserBlock
  end

  def forum_blocks? : Bool
    !forum_blocks.empty?
  end

  def forum_blocked_ids : Array(Int64)
    @forum_blocked_ids ||= forum_blocks.map(&.blocked_user_id)
  end

  def forum_blocked_usernames : Array(String)
    @forum_blocked_usernames ||= forum_blocks.map { |block| block.blocked_user.username }
  end

  def forum_blocks_user?(user_id : Int64) : Bool
    forum_blocked_ids.includes?(user_id)
  end
end
