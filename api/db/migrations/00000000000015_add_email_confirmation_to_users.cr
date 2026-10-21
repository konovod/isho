class AddEmailConfirmationToUsers::V00000000000015 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(User) do
      add email_confirmed_at : Time?
      add email_confirmation_token_hash : String?
      add email_confirmation_sent_at : Time?
    end

    # Accounts created before confirmation existed keep working: the same
    # addresses were already reachable, and nothing was verified for them.
    execute "UPDATE users SET email_confirmed_at = created_at"
  end

  def rollback
    alter table_for(User) do
      remove :email_confirmed_at
      remove :email_confirmation_token_hash
      remove :email_confirmation_sent_at
    end
  end
end
