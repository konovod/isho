class CreateProjects::V00000000000003 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Project) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to user : User, on_delete: :cascade
      add kind : String, default: "game"
      add title : String
      add slug : String, unique: true
      add tagline : String?
      add description : String?
      add status : String, default: "draft"
      add published_at : Time?
      add_index :status
      add_index :published_at
    end
  end

  def rollback
    drop table_for(Project)
  end
end
