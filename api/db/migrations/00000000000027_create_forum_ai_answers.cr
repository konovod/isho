class CreateForumAiAnswers::V00000000000027 < Avram::Migrator::Migration::V1
  def migrate
    # An AI answer is not a forum post on purpose: it must not change
    # replies_count, last_post_at, last_post_user_id or read markers.
    create table_for(ForumAiAnswer) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to topic : ForumTopic, on_delete: :cascade
      add body : String, default: ""
      add model : String, default: ""
      # queued | ready | failed | skipped
      add status : String, default: "queued"
      add error : String?
      add prompt_tokens : Int32, default: 0
      add completion_tokens : Int32, default: 0
    end

    # One answer per topic. `add_belongs_to` already created a plain index on
    # topic_id, so the unique one needs its own name.
    create_index table_for(ForumAiAnswer), :topic_id, unique: true, name: "forum_ai_answers_unique_topic"

    alter table_for(ForumSection) do
      add ai_answers_enabled : Bool, default: true
    end

    # Project discussions are created from the project page and are never
    # answered by the bot.
    execute <<-SQL
      UPDATE forum_sections SET ai_answers_enabled = false WHERE slug = 'projects'
    SQL
  end

  def rollback
    alter table_for(ForumSection) do
      remove :ai_answers_enabled
    end

    drop table_for(ForumAiAnswer)
  end
end
