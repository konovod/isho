class PrivateMessageQuery < PrivateMessage::BaseQuery
  # Messages either way between two accounts. A third account never matches,
  # so a conversation cannot leak through a guessed username.
  def between(first_user_id : Int64, second_user_id : Int64)
    where(
      "(private_messages.sender_id = ? AND private_messages.recipient_id = ?) OR " \
      "(private_messages.sender_id = ? AND private_messages.recipient_id = ?)",
      first_user_id, second_user_id, second_user_id, first_user_id,
    )
  end

  def for_recipient(user_id : Int64)
    recipient_id(user_id)
  end

  def from(user_id : Int64)
    sender_id(user_id)
  end

  def unread
    read_at.is_nil
  end

  def delivered_only
    delivered(true)
  end

  # A message is visible to its sender even when it was never delivered, so
  # the blocked author still sees their own side of the conversation.
  def visible_to(viewer_id : Int64)
    where("(private_messages.delivered = TRUE OR private_messages.sender_id = ?)", viewer_id)
  end

  # Safety net for counters: even an old unread row from a blocked account
  # must not light up the badge.
  def not_from_blocked(blocker_id : Int64)
    where(<<-SQL, blocker_id)
      private_messages.sender_id NOT IN (
        SELECT user_blocks.blocked_user_id
        FROM user_blocks
        WHERE user_blocks.blocker_id = ?
      )
    SQL
  end

  def older_than(message_id : Int64)
    id.lt(message_id)
  end

  def newer_than(message_id : Int64)
    id.gt(message_id)
  end

  def chronological
    created_at.asc_order.id.asc_order
  end

  def newest_first
    created_at.desc_order.id.desc_order
  end
end
