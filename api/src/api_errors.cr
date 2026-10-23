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

class Api::InvalidPasswordResetTokenError < Exception
  include Lucky::RenderableError

  def renderable_status : Int32
    422
  end

  def renderable_message : String
    "The password reset link is invalid or has expired"
  end
end

# A banned account can sign in and read, but every action that changes content
# is rejected until the ban expires or a moderator lifts it.
class Api::UserBannedError < Exception
  include Lucky::RenderableError

  def renderable_status : Int32
    403
  end

  def renderable_message : String
    "User is banned"
  end
end
