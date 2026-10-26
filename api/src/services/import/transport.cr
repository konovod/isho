require "http/client"
require "uri"

# The tiny bit of the network layer that specs replace, so the suite never
# reaches a real site. The fetcher owns redirects and the address checks; the
# backend only answers one request.
module Import::Transport
  record Response, status : Int32, headers : HTTP::Headers, body : Bytes

  abstract class Backend
    abstract def get(
      url : URI,
      headers : HTTP::Headers,
      timeout : Time::Span,
      max_bytes : Int64,
    ) : Response
  end

  class HTTPBackend < Backend
    def get(
      url : URI,
      headers : HTTP::Headers,
      timeout : Time::Span,
      max_bytes : Int64,
    ) : Response
      client = HTTP::Client.new(url)

      begin
        client.connect_timeout = 5.seconds
        client.read_timeout = timeout
        client.write_timeout = 10.seconds

        status = 0
        response_headers = HTTP::Headers.new
        body = Bytes.empty

        # The block form streams the body; the plain `exec` reads it all into
        # memory before we get a chance to check the limit.
        client.exec("GET", url.request_target, headers: headers) do |response|
          status = response.status_code
          response_headers = response.headers
          body = read_body(response.body_io, max_bytes) if response.body_io
        end

        Response.new(status, response_headers, body)
      rescue error : Import::Failed
        raise error
      rescue error
        raise Import::Unavailable.new("сеть: #{error.class}: #{error.message}")
      ensure
        # The connection may already be gone after a timeout.
        begin
          client.close
        rescue
        end
      end
    end

    # Reads until the limit and refuses to buffer more: a 300 MB page must not
    # land in the worker's memory.
    private def read_body(io : IO, max_bytes : Int64) : Bytes
      body = IO::Memory.new
      buffer = Bytes.new(16_384)

      while (read = io.read(buffer)) > 0
        body.write(buffer[0, read])
        raise Import::TooLarge.new("ответ больше #{max_bytes} байт") if body.size > max_bytes
      end

      body.to_slice
    end
  end

  # Replaced by the fake in spec/support/import_fake.cr.
  class_property backend : Backend = HTTPBackend.new
end
