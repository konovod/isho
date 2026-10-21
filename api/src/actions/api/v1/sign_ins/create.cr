class Api::V1::SignIns::Create < ApiAction
  include Api::Auth::SkipRequireSession
  include Lucky::RateLimit
  rate_limit to: 10, within: 10.minutes

  post "/api/v1/sign_ins" do
    SignInUser.run(params) do |operation, user|
      if user
        sign_in(user)
        json MeSerializer.new(user)
      else
        raise Avram::InvalidOperationError.new(operation)
      end
    end
  end

  private def rate_limit_identifier : String
    ip = context.request.remote_ip
    ip.nil? || ip.empty? ? "unknown" : ip
  end
end
