# One message in a private conversation. There is no conversation row: a
# thread is every message two accounts exchanged, and `read_at` marks what the
# recipient has already seen.
class PrivateMessage < BaseModel
  table do
    belongs_to sender : User
    belongs_to recipient : User
    column body : String
    column read_at : Time?
  end

  def read? : Bool
    !read_at.nil?
  end
end
