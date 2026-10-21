class AddTimestampsToProjectTags::V00000000000008 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(ProjectTag) do
      add created_at : Time, default: :now
      add updated_at : Time, default: :now
    end
  end

  def rollback
    alter table_for(ProjectTag) do
      remove :created_at
      remove :updated_at
    end
  end
end
