# This class handles error responses and reporting.
class Errors::Show < Lucky::ErrorAction
  DEFAULT_MESSAGE = "Something went wrong."
  default_format :json
  dont_report [Lucky::RouteNotFoundError, Avram::RecordNotFoundError, Api::ForbiddenError, Api::EmailNotConfirmedError, Api::InvalidEmailTokenError, Api::InvalidPasswordResetTokenError, Api::UserBannedError]

  def render(error : Lucky::RouteNotFoundError | Avram::RecordNotFoundError)
    error_json code: "not_found", message: "Not found", status: 404
  end

  def render(error : Api::EmailNotConfirmedError)
    error_json code: "email_not_confirmed", message: error.renderable_message, status: 403
  end

  def render(error : Api::InvalidEmailTokenError)
    error_json code: "invalid_token", message: error.renderable_message, status: 422
  end

  def render(error : Api::InvalidPasswordResetTokenError)
    error_json code: "invalid_token", message: error.renderable_message, status: 422
  end

  def render(error : Api::UserBannedError)
    error_json code: "user_banned", message: error.renderable_message, status: 403
  end

  def render(error : Avram::InvalidOperationError)
    details = error.errors.transform_keys(&.to_s)

    error_json(
      code: "validation_failed",
      message: "Validation failed",
      details: details,
      status: 422,
    )
  end

  # Always keep this below other 'render' methods or it may override your
  # custom 'render' methods.
  def render(error : Lucky::RenderableError)
    code = case error.renderable_status
           when 401 then "unauthorized"
           when 403 then "forbidden"
           when 404 then "not_found"
           when 429 then "too_many_requests"
           else          "error"
           end

    error_json code: code, message: error.renderable_message, status: error.renderable_status
  end

  def default_render(error : Exception) : Lucky::Response
    error_json code: "internal_error", message: DEFAULT_MESSAGE, status: 500
  end

  private def error_json(code : String, message : String, status : Int, details = nil)
    json ErrorSerializer.new(code: code, message: message, details: details), status: status
  end

  private def report(error : Exception) : Nil
    # Send to Rollbar, send an email, etc.
  end
end
