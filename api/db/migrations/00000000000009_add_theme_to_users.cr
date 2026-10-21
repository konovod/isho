class AddThemeToUsers::V00000000000009 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(User) do
      add theme : String, default: "dark"
    end
  end

  def rollback
    alter table_for(User) do
      remove :theme
    end
  end
end
