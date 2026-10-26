# A personal, one-way blacklist. The blocked account is never told about it:
# the row only changes what the blocker sees on the forum and in messages.
class CreateUserBlocks::V00000000000037 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(UserBlock) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to blocker : User, on_delete: :cascade
      add_belongs_to blocked_user : User, on_delete: :cascade
    end

    create_index table_for(UserBlock), [:blocker_id, :blocked_user_id], unique: true
  end

  def rollback
    drop table_for(UserBlock)
  end
end
