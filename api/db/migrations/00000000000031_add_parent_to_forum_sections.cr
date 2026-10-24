class AddParentToForumSections::V00000000000031 < Avram::Migrator::Migration::V1
  def migrate
    # Sections are a two-level tree: a root section may contain subsections.
    # The URL stays flat (/forum/:slug), so the parent is used for grouping and
    # breadcrumbs rather than for the path.
    alter table_for(ForumSection) do
      add_belongs_to parent : ForumSection?, on_delete: :restrict
    end
  end

  def rollback
    alter table_for(ForumSection) do
      remove_belongs_to :parent
    end
  end
end
