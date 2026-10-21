class Api::ForbiddenError < Exception
  include Lucky::RenderableError

  def renderable_status : Int32
    403
  end

  def renderable_message : String
    "Forbidden"
  end
end

# Publishing and forum writing need a confirmed address. The frontend turns the
# code into a hint with a resend button.
class Api::EmailNotConfirmedError < Exception
  include Lucky::RenderableError

  def renderable_status : Int32
    403
  end

  def renderable_message : String
    "Email is not confirmed"
  end
end

class Api::InvalidEmailTokenError < Exception
  include Lucky::RenderableError

  def renderable_status : Int32
    422
  end

  def renderable_message : String
    "The confirmation link is invalid or has expired"
  end
end
