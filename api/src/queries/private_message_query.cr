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
