class AppServer < Lucky::BaseAppServer
  # Learn about middleware with HTTP::Handlers:
  # https://luckyframework.org/guides/http-and-routing/http-handlers
  def middleware : Array(HTTP::Handler)
    [
      Lucky::RequestIdHandler.new,
      Lucky::ForceSSLHandler.new,
      Lucky::LogHandler.new,
      Lucky::ErrorHandler.new(action: Errors::Show),
      Lucky::RemoteIpHandler.new,
      RequestSizeLimitHandler.new,
      Lucky::RouteHandler.new,
      MediaHeadersHandler.new,
      Lucky::StaticFileHandler.new("./public", fallthrough: true, directory_listing: false),
      Lucky::RouteNotFoundHandler.new,
    ] of HTTP::Handler
  end

  def protocol
    "http"
  end

  def listen
    server.listen(host, port, reuse_port: false)
  end
end
