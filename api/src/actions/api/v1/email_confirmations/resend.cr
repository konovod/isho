class Api::V1::EmailConfirmations::Resend < ApiAction
  include Lucky::RateLimit
  rate_limit to: 3, within: 10.minutes

  post "/api/v1/email_confirmations/resend" do
    user = current_user

    if user.email_confirmed?
      return json({sent: false, already_confirmed: true})
    end

    if remaining = EmailConfirmation.resend_in(user)
      return json({sent: false, retry_after: remaining.total_seconds.ceil.to_i})
    end

    begin
      EmailConfirmation.send_to(user)
    rescue error
      Log.error(exception: error) { "Could not send the confirmation email" }

      return json(ErrorSerializer.new(
        code: "email_delivery_failed",
        message: "Could not send the email",
      ), status: 502)
    end

    json({sent: true, retry_after: AppSettings::EMAIL_CONFIRMATION_RESEND_INTERVAL.total_seconds.to_i})
  end

  private def rate_limit_identifier : String
    current_user?.try(&.id).try(&.to_s) || "unknown"
  end
end
