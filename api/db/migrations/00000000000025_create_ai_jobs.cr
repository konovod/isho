class CreateAiJobs::V00000000000025 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(AiJob) do
      primary_key id : Int64
      add_timestamps
      # forum_answer | flair
      add kind : String
      add_belongs_to user : User, on_delete: :cascade
      add_belongs_to topic : ForumTopic?, on_delete: :cascade
      # queued | running | done | failed | skipped
      add status : String, default: "queued"
      add attempts : Int32, default: 0
      add run_after : Time
      add started_at : Time?
      add finished_at : Time?
      add error : String?
      add prompt_tokens : Int32, default: 0
      add completion_tokens : Int32, default: 0
    end

    # The worker polls only queued jobs that are due.
    create_index table_for(AiJob), [:status, :run_after]
    # A topic gets at most one answer job, so a retried request cannot spend
    # tokens twice.
    execute <<-SQL
      CREATE UNIQUE INDEX ai_jobs_forum_answer_topic
      ON ai_jobs (topic_id)
      WHERE kind = 'forum_answer'
    SQL
    create_index table_for(AiJob), [:kind, :user_id, :created_at]
    create_index table_for(AiJob), :created_at
  end

  def rollback
    drop table_for(AiJob)
  end
end
