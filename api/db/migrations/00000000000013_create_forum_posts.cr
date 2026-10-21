class CreateForumPosts::V00000000000013 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(ForumPost) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to topic : ForumTopic, on_delete: :cascade
      add_belongs_to user : User, on_delete: :cascade
      add body : String
      add quoted_post_id : Int64?
      add quote_author_name : String?
      add quote_author_username : String?
      add quote_body : String?
    end

    create_index table_for(ForumPost), [:topic_id, :created_at]
  end

  def rollback
    drop table_for(ForumPost)
  end
end
