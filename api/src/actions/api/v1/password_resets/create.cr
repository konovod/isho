class Api::V1::PasswordResets::Create < ApiAction
  include Api::Auth::SkipRequireSession
  include Lucky::RateLimit
  rate_limit to: 10, within: 10.minutes

  post "/api/v1/password_resets" do
    RequestPasswordReset.run(params) do |operation, user|
      unless operation.valid?
        raise Avram::InvalidOperationError.new(operation)
      end

      # Every address gets the same answer. A mail failure is logged instead of
      # returned, otherwise the response would reveal that the account exists.
      if user
        begin
          PasswordReset.deliver(user)
        rescue error
          Log.error(exception: error) { "Could not send the password reset email" }
        end
      end

      json({sent: true})
    end
  end

  private def rate_limit_identifier : String
    ip = context.request.remote_ip
    ip.nil? || ip.empty? ? "unknown" : ip
  end
end
