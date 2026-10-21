class CreateDevlogs::V00000000000010 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Devlog) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to project : Project, on_delete: :cascade
      add title : String
      add slug : String
      add body : String
    end

    create_index table_for(Devlog), [:project_id, :slug], unique: true
  end

  def rollback
    drop table_for(Devlog)
  end
end
