# Publishing projects and writing on the forum requires a reachable address.
# Included by the actions that create public content.
module Api::Auth::RequireConfirmedEmail
  macro included
    before require_confirmed_email
  end

  private def require_confirmed_email
    if current_user.email_confirmed?
      continue
    else
      raise Api::EmailNotConfirmedError.new
    end
  end
end
