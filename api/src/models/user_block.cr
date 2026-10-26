# One personal block. The pair is unique, and neither account is notified:
# a block only changes what the blocker sees.
class UserBlock < BaseModel
  table do
    belongs_to blocker : User
    belongs_to blocked_user : User
  end
end
