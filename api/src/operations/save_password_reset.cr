# Stores a fresh reset token digest. Only the hash is kept: the raw token
# travels in the email link, the same way EmailConfirmation does it.
class SavePasswordReset < User::SaveOperation
  permit_columns password_reset_token_hash, password_reset_sent_at
end
