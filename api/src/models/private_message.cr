# One message in a private conversation. There is no conversation row: a
# thread is every message two accounts exchanged, and `read_at` marks what the
# recipient has already seen.
class PrivateMessage < BaseModel
  table do
    belongs_to sender : User
    belongs_to recipient : User
    column body : String
    column read_at : Time?
    # False when the recipient blocked the sender: the sender keeps the
    # message in their own conversation, the recipient never sees it.
    column delivered : Bool
  end

  def read? : Bool
    !read_at.nil?
  end
end
