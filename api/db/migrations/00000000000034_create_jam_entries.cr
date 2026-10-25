class CreateJamEntries::V00000000000034 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(JamEntry) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to jam : Jam, on_delete: :cascade
      add_belongs_to project : Project, on_delete: :cascade
      # Multiple projects from one account are allowed; the same project cannot
      # enter the same jam twice.
      add_belongs_to user : User, on_delete: :cascade
      add status : String, default: "submitted"
      add disqualified_reason : String?
      add disqualified_at : Time?
      add_belongs_to disqualified_by : User?, on_delete: :nullify
      add_index :status
    end

    create_index table_for(JamEntry), [:jam_id, :project_id], unique: true
  end

  def rollback
    drop table_for(JamEntry)
  end
end
