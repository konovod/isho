# The raw confirmation token exists only inside the delivered letter.
def confirmation_token_from_last_email : String
  body = Carbon::DevAdapter.delivered_emails.last.text_body.to_s
  match = body.match(/token=([A-Za-z0-9_\-]+)/)
  raise "No confirmation token in the delivered email:\n#{body}" unless match

  match[1]
end
