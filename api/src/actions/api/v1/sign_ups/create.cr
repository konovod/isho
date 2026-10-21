class Api::V1::SignUps::Create < ApiAction
  include Api::Auth::SkipRequireSession
  include Lucky::RateLimit
  rate_limit to: 5, within: 10.minutes

  post "/api/v1/sign_ups" do
    user = SignUpUser.create!(params)
    sign_in(user)
    json MeSerializer.new(user), status: 201
  end

  private def rate_limit_identifier : String
    ip = context.request.remote_ip
    ip.nil? || ip.empty? ? "unknown" : ip
  end
end
