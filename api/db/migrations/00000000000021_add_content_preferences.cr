class AddContentPreferences::V00000000000021 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(Project) do
      # Adult projects are hidden from visitors and from accounts that turned
      # them off. Existing projects stay visible.
      add nsfw : Bool, default: false
      # Highest AI involvement used to make the project. See AppSettings.
      add ai_usage : String, default: "ai_free"
      add_index :nsfw
    end

    alter table_for(User) do
      add show_nsfw : Bool, default: true
      add max_ai_usage : String, default: "full"
    end
  end

  def rollback
    alter table_for(User) do
      remove :max_ai_usage
      remove :show_nsfw
    end

    alter table_for(Project) do
      remove :nsfw
      remove :ai_usage
    end
  end
end
