# An address that cannot register again. Entries are created when an admin
# deletes an account; the user row itself is gone by then.
class BlockedEmail < BaseModel
  table do
    column email : String
    column username : String?
  end
end
