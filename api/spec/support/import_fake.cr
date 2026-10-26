# Specs never reach a real site. The fake answers by exact URL and records what
# was asked, so the examples can check which addresses the import touched.
class ImportFakeBackend < Import::Transport::Backend
  getter requests = [] of String
  getter responses = {} of String => Import::Transport::Response

  def get(
    url : URI,
    headers : HTTP::Headers,
    timeout : Time::Span,
    max_bytes : Int64,
  ) : Import::Transport::Response
    requests << url.to_s
    responses[url.to_s]? || Import::Transport::Response.new(404, HTTP::Headers.new, Bytes.empty)
  end

  def stub(
    url : String,
    body : String,
    status : Int32 = 200,
    content_type : String = "text/html; charset=utf-8",
  ) : Nil
    responses[url] = Import::Transport::Response.new(
      status,
      HTTP::Headers{"Content-Type" => content_type},
      body.to_slice,
    )
  end

  def stub_bytes(url : String, body : Bytes, content_type : String) : Nil
    responses[url] = Import::Transport::Response.new(
      200,
      HTTP::Headers{"Content-Type" => content_type},
      body,
    )
  end

  def stub_redirect(url : String, location : String, status : Int32 = 302) : Nil
    responses[url] = Import::Transport::Response.new(
      status,
      HTTP::Headers{"Location" => location},
      Bytes.empty,
    )
  end
end

def import_fake : ImportFakeBackend
  Import::Transport.backend.as(ImportFakeBackend)
end

# Public and private hosts the fake resolver knows about; anything else is a
# public address, so a spec can check redirects and paths without DNS.
def stub_dns : Nil
  Import::UrlGuard.resolver = ->(host : String, port : Int32) do
    case host
    when "localhost"
      [Socket::IPAddress.new("127.0.0.1", port)]
    when "10.0.0.5"
      [Socket::IPAddress.new("10.0.0.5", port)]
    when "metadata"
      [Socket::IPAddress.new("169.254.169.254", port)]
    else
      [Socket::IPAddress.new("93.184.216.34", port)]
    end
  end
end
