# Where the draft was imported from. Only the author and moderators see it, and
# it outlives the import job, which is removed after a month.
class AddSourceUrlToProjects::V00000000000042 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(Project) do
      add source_url : String?
    end
  end

  def rollback
    alter table_for(Project) do
      remove :source_url
    end
  end
end
