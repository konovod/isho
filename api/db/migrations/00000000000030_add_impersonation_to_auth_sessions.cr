class AddImpersonationToAuthSessions::V00000000000030 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(AuthSession) do
      # Set on the short session an admin opens to view the site as another
      # account. Such a session is only honoured together with the admin's own
      # session cookie, so its token is useless on its own.
      add impersonator_id : Int64?
      add_index :impersonator_id
    end
  end

  def rollback
    alter table_for(AuthSession) do
      remove :impersonator_id
    end
  end
end
