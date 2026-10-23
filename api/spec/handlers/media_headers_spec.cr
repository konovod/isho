require "../spec_helper"

private def handler_headers(method : String, path : String) : {HTTP::Server::Response, HTTP::Headers}
  request = HTTP::Request.new(method, path)
  response = HTTP::Server::Response.new(IO::Memory.new)
  context = HTTP::Server::Context.new(request, response)

  handler = MediaHeadersHandler.new
  # Without a next handler, HTTP::Handler writes a 404 and closes the response,
  # so end the chain with a no-op.
  handler.next = ->(ctx : HTTP::Server::Context) { }
  handler.call(context)

  {response, response.headers}
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
