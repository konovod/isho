class ApiClient < Lucky::BaseHTTPClient
  app AppServer.new

  def initialize
    super
    headers("Content-Type": "application/json", "Accept": "application/json")
  end

  def with_cookie(token : String) : self
    headers("Cookie": "#{Api::Auth::Helpers.cookie_name}=#{token}")
  end

  # Impersonation needs both cookies: the admin session and the target view.
  def with_cookies(cookies : Hash(String, String)) : self
    header = cookies.map { |name, value| "#{name}=#{value}" }.join("; ")
    headers("Cookie": header)
  end
end
