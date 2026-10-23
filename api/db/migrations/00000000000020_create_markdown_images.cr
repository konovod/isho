class CreateMarkdownImages::V00000000000020 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(MarkdownImage) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to user : User, on_delete: :cascade
      add image : JSON::Any?
    end
  end

  def rollback
    drop table_for(MarkdownImage)
  end
end
