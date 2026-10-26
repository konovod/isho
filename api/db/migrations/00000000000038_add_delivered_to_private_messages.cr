# Messages sent to someone who blocked the author are accepted silently but
# never delivered: the sender keeps them in the conversation, the recipient
# never sees them.
class AddDeliveredToPrivateMessages::V00000000000038 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(PrivateMessage) do
      add delivered : Bool, default: true
    end
  end

  def rollback
    alter table_for(PrivateMessage) do
      remove :delivered
    end
  end
end
