class AddAiFlairToUsers::V00000000000024 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(User) do
      # A short AI-made characteristic shown under the nickname on the forum.
      # It is rebuilt from the latest posts at most once a day.
      add ai_flair : String?
      add ai_flair_at : Time?
      # Users can hide their flair without deleting the row.
      add ai_flair_enabled : Bool, default: true
    end
  end

  def rollback
    alter table_for(User) do
      remove :ai_flair_enabled
      remove :ai_flair_at
      remove :ai_flair
    end
  end
end
