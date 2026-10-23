class CreateBuilds::V00000000000022 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Build) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to project : Project, on_delete: :cascade
      # Browser builds are served from /media/web/<public_id>/..., so the
      # identifier must not be guessable from a draft project's id.
      add public_id : String, unique: true
      add kind : String
      add label : String
      add platform : String?
      add version : String?
      add stored_file : JSON::Any?
      add entry_path : String?
      add size_bytes : Int64, default: 0
    end
  end

  def rollback
    drop table_for(Build)
  end
end
