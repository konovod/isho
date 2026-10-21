class CreateTags::V00000000000005 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Tag) do
      primary_key id : Int64
      add_timestamps
      add name : String
      add slug : String, unique: true
    end
  end

  def rollback
    drop table_for(Tag)
  end
end
