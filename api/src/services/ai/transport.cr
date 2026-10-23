# The tiny bit of the network layer that specs replace. Keeping it behind one
# abstract class means the suite never talks to a real provider.
module Ai::Transport
  abstract class Backend
    abstract def post(
      url : String,
      headers : HTTP::Headers,
      body : String,
      timeout : Time::Span,
    ) : {Int32, String}
  end

  class HTTPBackend < Backend
    def post(
      url : String,
      headers : HTTP::Headers,
      body : String,
      timeout : Time::Span,
    ) : {Int32, String}
      uri = URI.parse(url)
      client = HTTP::Client.new(uri)

      begin
        client.connect_timeout = 5.seconds
        client.read_timeout = timeout
        client.write_timeout = 10.seconds
        response = client.post(uri.request_target, headers: headers, body: body)
        {response.status_code, response.body}
      ensure
        client.close
      end
    end
  end

  # Replaced by the fake in spec/support/ai_fake.cr. The real backend stays the
  # default so production needs no extra wiring.
  class_property backend : Backend = HTTPBackend.new
end
