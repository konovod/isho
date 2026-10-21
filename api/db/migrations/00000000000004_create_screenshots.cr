class CreateScreenshots::V00000000000004 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Screenshot) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to project : Project, on_delete: :cascade
      add image : JSON::Any?
      add caption : String?
      add position : Int32, default: 0
      add is_cover : Bool, default: false
    end
  end

  def rollback
    drop table_for(Screenshot)
  end
end
