class CreateForumPostReactions::V00000000000028 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(ForumPostReaction) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to post : ForumPost, on_delete: :cascade
      add_belongs_to user : User, on_delete: :cascade
      add kind : String
    end

    # One voice per user and post; the second index serves the voter popup.
    create_index table_for(ForumPostReaction), [:post_id, :user_id], unique: true
    create_index table_for(ForumPostReaction), [:post_id, :kind, :created_at]
  end

  def rollback
    drop table_for(ForumPostReaction)
  end
end
