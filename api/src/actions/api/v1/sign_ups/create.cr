class Api::V1::SignUps::Create < ApiAction
  include Api::Auth::SkipRequireSession
  include Lucky::RateLimit
  rate_limit to: 5, within: 10.minutes

  post "/api/v1/sign_ups" do
    user = SignUpUser.create!(params)

    if EmailConfirmation.required?
      send_confirmation(user)
    else
      user = ConfirmUserEmail.update!(user, email_confirmed_at: Time.utc)
    end

    sign_in(user)
    json MeSerializer.new(user), status: 201
  end

  # The account already exists at this point, so a mail problem must not fail
  # the registration. The user can ask for another letter from the dashboard.
  private def send_confirmation(user : User) : Nil
    EmailConfirmation.send_to(user)
  rescue error
    Log.error(exception: error) { "Could not send the confirmation email" }
  end

  private def rate_limit_identifier : String
    ip = context.request.remote_ip
    ip.nil? || ip.empty? ? "unknown" : ip
  end
end
