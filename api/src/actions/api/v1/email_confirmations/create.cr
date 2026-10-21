class Api::V1::EmailConfirmations::Create < ApiAction
  include Api::Auth::SkipRequireSession
  include Lucky::RateLimit
  rate_limit to: 10, within: 10.minutes

  post "/api/v1/email_confirmations" do
    user = EmailConfirmation.confirm(params.get?(:token).to_s)

    if user
      json({confirmed: true, email: user.email})
    else
      raise Api::InvalidEmailTokenError.new
    end
  end

  private def rate_limit_identifier : String
    ip = context.request.remote_ip
    ip.nil? || ip.empty? ? "unknown" : ip
  end
end
