# Read markers used to be a count from the start of the topic, which cannot
# ignore posts by blocked authors. The last seen post id is the real marker;
# `read_count` stays for compatibility with older clients.
class AddLastPostToForumTopicReads::V00000000000039 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(ForumTopicRead) do
      add last_post_id : Int64?
    end

    execute <<-SQL
      UPDATE forum_topic_reads SET last_post_id = CASE
        WHEN read_count > 0 THEN (
          SELECT forum_posts.id FROM forum_posts
          WHERE forum_posts.topic_id = forum_topic_reads.topic_id
          ORDER BY forum_posts.id
          OFFSET forum_topic_reads.read_count - 1
          LIMIT 1
        )
        ELSE NULL
      END
    SQL
  end

  def rollback
    alter table_for(ForumTopicRead) do
      remove :last_post_id
    end
  end
end
