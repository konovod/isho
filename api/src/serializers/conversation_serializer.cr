class ConversationSerializer < BaseSerializer
  def initialize(@entry : DirectMessages::InboxEntry)
  end

  def render
    {
      peer:         UserSerializer.new(@entry.peer),
      last_message: {
        id:         @entry.message_id,
        body:       @entry.body,
        mine:       @entry.mine,
        created_at: @entry.created_at,
      },
      unread_count: @entry.unread_count,
    }
  end
end
