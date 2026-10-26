class PrivateMessageSerializer < BaseSerializer
  # `mine` lets the chat align the bubble without comparing ids on the client;
  # `viewer_id` is the account the site currently acts as.
  def initialize(@message : PrivateMessage, @viewer_id : Int64)
  end

  def render
    {
      id:         @message.id,
      body:       @message.body,
      author:     UserSerializer.new(@message.sender),
      mine:       @message.sender_id == @viewer_id,
      created_at: @message.created_at,
    }
  end
end
