class CreatePrivateMessages::V00000000000036 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(PrivateMessage) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to sender : User, on_delete: :cascade
      add_belongs_to recipient : User, on_delete: :cascade
      add body : String
      add read_at : Time?
    end

    # The chat reads one pair in both directions; the unread counter looks at
    # the recipient side only.
    create_index table_for(PrivateMessage), [:sender_id, :recipient_id, :created_at]
    create_index table_for(PrivateMessage), [:recipient_id, :sender_id, :read_at]
  end

  def rollback
    drop table_for(PrivateMessage)
  end
end
