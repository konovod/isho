module AuthHelper
  def self.token_for(user : User) : String
    _, token = ::Auth::Session.start(user)
    token
  end

  def self.client_for(user : User) : ApiClient
    ApiClient.new.with_cookie(token_for(user))
  end
end
