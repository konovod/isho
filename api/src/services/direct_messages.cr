# Private conversations are a pair of accounts, not a stored thread: one
# conversation is every message the two exchanged. The inbox still needs the
# last message and the unread count per peer, which is one SQL query.
module DirectMessages
  record InboxEntry,
    peer : User,
    message_id : Int64,
    body : String,
    mine : Bool,
    created_at : Time,
    unread_count : Int32

  def self.inbox(user : User) : Array(InboxEntry)
    rows = AppDatabase.run do |db|
      db.query_all(INBOX_SQL, user.id, as: {Int64, Int64, String, Int64, Time, Int64}).to_a
    end
    return [] of InboxEntry if rows.empty?

    peers = UserQuery.new.id.in(rows.map(&.[0])).results.index_by(&.id)

    rows.compact_map do |row|
      peer_id, message_id, body, sender_id, created_at, unread = row
      peer = peers[peer_id]?
      next unless peer

      InboxEntry.new(
        peer: peer,
        message_id: message_id,
        body: body,
        mine: sender_id == user.id,
        created_at: created_at,
        unread_count: unread.to_i32,
      )
    end
  end

  def self.unread_count(user : User) : Int64
    PrivateMessageQuery.new
      .for_recipient(user.id)
      .unread
      .delivered_only
      .not_from_blocked(user.id)
      .select_count
  end

  # One row per peer with the latest message; the unread counter is per peer
  # and counts only what that peer sent to this account.
  private INBOX_SQL = <<-SQL
    WITH mine AS (
      SELECT
        private_messages.id,
        private_messages.body,
        private_messages.sender_id,
        private_messages.created_at,
        CASE
          WHEN private_messages.sender_id = $1 THEN private_messages.recipient_id
          ELSE private_messages.sender_id
        END AS peer_id
      FROM private_messages
      WHERE (private_messages.sender_id = $1 OR private_messages.recipient_id = $1)
        AND (private_messages.delivered = TRUE OR private_messages.sender_id = $1)
    ),
    last AS (
      SELECT DISTINCT ON (peer_id) peer_id, id, body, sender_id, created_at
      FROM mine
      ORDER BY peer_id, created_at DESC, id DESC
    )
    SELECT
      last.peer_id,
      last.id,
      last.body,
      last.sender_id,
      last.created_at,
      (
        SELECT COUNT(*)
        FROM private_messages unread
        WHERE unread.sender_id = last.peer_id
          AND unread.recipient_id = $1
          AND unread.read_at IS NULL
          AND unread.delivered = TRUE
          AND unread.sender_id NOT IN (
            SELECT blocked_user_id FROM user_blocks WHERE blocker_id = $1
          )
      )::bigint AS unread_count
    FROM last
    ORDER BY last.created_at DESC, last.id DESC
    SQL
end
