class CreateDownloads::V00000000000007 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Download) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to project : Project, on_delete: :cascade
      add label : String
      add url : String
      add platform : String?
      add version : String?
    end
  end

  def rollback
    drop table_for(Download)
  end
end
