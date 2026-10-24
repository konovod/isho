require "../spec_helper"

private def handler_headers(method : String, path : String, host : String? = nil) : {HTTP::Server::Response, HTTP::Headers}
  request = HTTP::Request.new(method, path)
  request.headers["Host"] = host if host
  response = HTTP::Server::Response.new(IO::Memory.new)
  context = HTTP::Server::Context.new(request, response)

  handler = MediaHeadersHandler.new
  # Without a next handler, HTTP::Handler writes a 404 and closes the response,
  # so end the chain with a no-op.
  handler.next = ->(ctx : HTTP::Server::Context) { }
  handler.call(context)

  {response, response.headers}
end

private def with_media_origin(value : String, &)
  previous = ENV["MEDIA_ORIGIN"]?
  ENV["MEDIA_ORIGIN"] = value
  begin
    yield
  ensure
    previous ? (ENV["MEDIA_ORIGIN"] = previous) : ENV.delete("MEDIA_ORIGIN")
  end
end

describe MediaHeadersHandler do
  it "sandboxes browser builds and allows CORS reads" do
    _, headers = handler_headers("GET", "/media/web/abc/index.html")

    headers["Content-Security-Policy"].should contain("sandbox")
    headers["Content-Security-Policy"].should_not contain("allow-same-origin")
    headers["Access-Control-Allow-Origin"].should eq("*")
    headers["X-Content-Type-Options"].should eq("nosniff")
  end

  it "answers preflights for browser builds" do
    response, headers = handler_headers("OPTIONS", "/media/web/abc/index.html")

    response.status_code.should eq(204)
    headers["Access-Control-Allow-Origin"].should eq("*")
    headers["Access-Control-Allow-Methods"].should contain("GET")
  end

  it "keeps the media host's own origin for cache storage and saves" do
    with_media_origin("https://games.example.test") do
      _, headers = handler_headers("GET", "/media/web/abc/index.html", host: "games.example.test")

      headers["Content-Security-Policy"].should contain("allow-same-origin")
    end
  end

  it "gives every project host its own origin too" do
    with_media_origin("https://games.example.test") do
      _, headers = handler_headers("GET", "/media/web/abc/index.html", host: "nectaris.games.example.test")

      headers["Content-Security-Policy"].should contain("allow-same-origin")
    end
  end

  it "never allows the app origin back through the play URL" do
    with_media_origin("https://games.example.test") do
      _, headers = handler_headers("GET", "/media/web/abc/index.html", host: "isho.example.test")

      headers["Content-Security-Policy"].should_not contain("allow-same-origin")
    end
  end

  it "serves downloadable builds as attachments" do
    _, headers = handler_headers("GET", "/media/build/abc/files/game.zip")

    headers["Content-Disposition"].should eq("attachment")
    headers["X-Content-Type-Options"].should eq("nosniff")
  end

  it "leaves other media alone" do
    _, headers = handler_headers("GET", "/media/screenshot/1/image/file.jpg")

    headers["Content-Disposition"]?.should be_nil
    headers["Content-Security-Policy"]?.should be_nil
  end
end
