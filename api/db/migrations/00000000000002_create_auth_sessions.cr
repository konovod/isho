class CreateAuthSessions::V00000000000002 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(AuthSession) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to user : User, on_delete: :cascade
      add token_hash : String, unique: true
      add expires_at : Time
      add user_agent : String?
      add ip : String?
    end
  end

  def rollback
    drop table_for(AuthSession)
  end
end
