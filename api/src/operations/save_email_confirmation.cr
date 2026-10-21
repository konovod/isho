# Stores a new confirmation token digest. Only the hash is kept: the raw token
# travels in the email link, the same way Auth::Session keeps its cookie token.
class SaveEmailConfirmation < User::SaveOperation
  permit_columns email_confirmation_token_hash, email_confirmation_sent_at
end
