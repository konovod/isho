# An upload in progress. The declared size counts against the quotas from the
# first chunk, so two parallel uploads cannot slip past a limit together.
class CreateUploadSessions::V00000000000023 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(UploadSession) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to user : User, on_delete: :cascade
      add_belongs_to project : Project, on_delete: :cascade
      add token : String, unique: true
      add kind : String
      add filename : String
      add total_bytes : Int64
      add received_bytes : Int64, default: 0
    end
  end

  def rollback
    drop table_for(UploadSession)
  end
end
