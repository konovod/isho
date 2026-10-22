class AddForumReadTracking::V00000000000016 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(ForumTopic) do
      add_belongs_to last_post_user : User?, on_delete: :nullify
    end

    # Existing topics already have their last message, so fill the author in
    # right away and avoid an extra join when listing topics.
    execute <<-SQL
      UPDATE forum_topics SET last_post_user_id = (
        SELECT forum_posts.user_id FROM forum_posts
        WHERE forum_posts.topic_id = forum_topics.id
        ORDER BY forum_posts.created_at DESC, forum_posts.id DESC
        LIMIT 1
      )
    SQL

    create table_for(ForumTopicRead) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to user : User, on_delete: :cascade
      add_belongs_to topic : ForumTopic, on_delete: :cascade
      add read_count : Int32, default: 0
    end

    create_index table_for(ForumTopicRead), [:user_id, :topic_id], unique: true
  end

  def rollback
    drop table_for(ForumTopicRead)

    alter table_for(ForumTopic) do
      remove :last_post_user_id
    end
  end
end
