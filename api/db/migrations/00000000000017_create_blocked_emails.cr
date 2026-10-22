class CreateBlockedEmails::V00000000000017 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(BlockedEmail) do
      primary_key id : Int64
      add_timestamps
      # Same type as users.email: the address is unique regardless of case.
      add email : String, unique: true, case_sensitive: false
      # Snapshot of the deleted account, so the moderation list has context
      # after the user row is gone.
      add username : String?
    end
  end

  def rollback
    drop table_for(BlockedEmail)
  end
end
