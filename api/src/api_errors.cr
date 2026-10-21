class Api::ForbiddenError < Exception
  include Lucky::RenderableError

  def renderable_status : Int32
    403
  end

  def renderable_message : String
    "Forbidden"
  end
end
