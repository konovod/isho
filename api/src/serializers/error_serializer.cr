class ErrorSerializer < BaseSerializer
  def initialize(
    @code : String,
    @message : String,
    @details : Hash(String, Array(String))? = nil,
  )
  end

  def render
    {error: {code: @code, message: @message, details: @details}}
  end
end
