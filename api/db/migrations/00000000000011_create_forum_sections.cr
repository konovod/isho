class CreateForumSections::V00000000000011 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(ForumSection) do
      primary_key id : Int64
      add_timestamps
      add title : String
      add slug : String, unique: true
      add description : String?
      add group_title : String?
      add position : Int32, default: 0
    end
  end

  def rollback
    drop table_for(ForumSection)
  end
end
