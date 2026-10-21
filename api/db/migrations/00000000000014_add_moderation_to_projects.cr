class AddModerationToProjects::V00000000000014 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(Project) do
      add moderation_note : String?
      add moderated_at : Time?
      add_belongs_to moderated_by : User?, on_delete: :nullify
    end
  end

  def rollback
    alter table_for(Project) do
      remove :moderated_by_id
      remove :moderated_at
      remove :moderation_note
    end
  end
end
