class CreateForumTopics::V00000000000012 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(ForumTopic) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to section : ForumSection, on_delete: :cascade
      add_belongs_to user : User, on_delete: :cascade
      add_belongs_to project : Project?, on_delete: :cascade
      add title : String
      add slug : String
      add replies_count : Int32, default: 0
      add last_post_at : Time
    end

    create_index table_for(ForumTopic), [:section_id, :slug], unique: true
    create_index table_for(ForumTopic), [:section_id, :last_post_at]
  end

  def rollback
    drop table_for(ForumTopic)
  end
end
