class ApiClient < Lucky::BaseHTTPClient
  app AppServer.new

  def initialize
    super
    headers("Content-Type": "application/json", "Accept": "application/json")
  end

  def with_cookie(token : String) : self
    headers("Cookie": "isho_auth=#{token}")
  end
end
