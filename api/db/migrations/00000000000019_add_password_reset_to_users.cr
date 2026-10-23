class AddPasswordResetToUsers::V00000000000019 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(User) do
      # Only the SHA-256 digest of the link token is stored, never the token
      # itself. A fresh request overwrites both columns.
      add password_reset_token_hash : String?
      add password_reset_sent_at : Time?
    end
  end

  def rollback
    alter table_for(User) do
      remove :password_reset_token_hash
      remove :password_reset_sent_at
    end
  end
end
