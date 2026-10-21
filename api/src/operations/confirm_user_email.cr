# Marks the address as reachable and drops the one-time token.
class ConfirmUserEmail < User::SaveOperation
  permit_columns email_confirmed_at, email_confirmation_token_hash, email_confirmation_sent_at
end
