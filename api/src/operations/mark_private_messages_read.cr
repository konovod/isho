# Marks everything the peer sent as read in one statement. Repeated calls are
# harmless: the query only touches rows with a missing `read_at`.
class MarkPrivateMessagesRead < Avram::Operation
  needs user : User
  needs peer : User

  def run
    PrivateMessageQuery.new
      .for_recipient(user.id)
      .from(peer.id)
      .unread
      .delivered_only
      .update(read_at: Time.utc)
  end
end
