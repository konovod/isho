class CreateProjectTags::V00000000000006 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(ProjectTag) do
      primary_key id : Int64
      add_belongs_to project : Project, on_delete: :cascade
      add_belongs_to tag : Tag, on_delete: :cascade
    end

    execute "CREATE UNIQUE INDEX project_tags_project_id_tag_id_index ON project_tags (project_id, tag_id)"
  end

  def rollback
    drop table_for(ProjectTag)
  end
end
