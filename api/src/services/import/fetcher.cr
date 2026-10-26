require "uri"

# Fetches one page or one image with the limits an import needs: a public
# address, a few redirects, a deadline and a size cap. Nothing else in the
# import touches the network.
module Import::Fetcher
  USER_AGENT    = "isho-import/1.0"
  HTML_TYPES    = %w[text/html application/xhtml+xml]
  MAX_BYTES     = AppSettings::IMPORT_MAX_PAGE_BYTES
  MAX_REDIRECTS = AppSettings::IMPORT_REDIRECTS

  record Fetched, url : URI, content_type : String, body : Bytes do
    def text : String
      String.new(body)
    end

    def html? : Bool
      HTML_TYPES.any? { |type| content_type.downcase.starts_with?(type) }
    end
  end

  # The author's link. Only HTML is accepted: a PDF or a ZIP at that address
  # means the link is wrong.
  def self.page(raw_url : String) : Fetched
    fetched = fetch(
      raw_url,
      max_bytes: MAX_BYTES,
      accept: "text/html,application/xhtml+xml;q=0.9",
      timeout: AppSettings::IMPORT_TIMEOUT,
    )

    unless fetched.html?
      raise Import::Failed.new("по ссылке не страница, а #{describe(fetched.content_type)}")
    end

    fetched
  end

  # An image for a screenshot. The type is decided by the bytes later, because
  # CDNs often answer `application/octet-stream`.
  def self.image(raw_url : String) : Fetched
    fetch(
      raw_url,
      max_bytes: AppSettings::SCREENSHOT_MAX_BYTES,
      accept: "image/*;q=1.0,*/*;q=0.1",
      timeout: AppSettings::IMPORT_TIMEOUT,
    )
  end

  # A documented API of a site we read (Steam's store endpoint). Still goes
  # through the same address checks: it is a URL built from user input.
  def self.json(raw_url : String) : Fetched
    fetch(
      raw_url,
      max_bytes: MAX_BYTES,
      accept: "application/json",
      timeout: AppSettings::IMPORT_TIMEOUT,
    )
  end

  private def self.fetch(
    raw_url : String,
    max_bytes : Int64,
    accept : String,
    timeout : Time::Span,
  ) : Fetched
    uri = Import::UrlGuard.check(raw_url)
    redirects = 0

    loop do
      response = Import::Transport.backend.get(uri, headers(accept), timeout, max_bytes)

      case response.status
      when 200
        check_encoding!(response.headers)
        return Fetched.new(uri, response.headers["Content-Type"]?.to_s, response.body)
      when 301, 302, 303, 307, 308
        location = response.headers["Location"]?
        raise Import::Failed.new("перенаправление без адреса") unless location

        redirects += 1
        raise Import::Failed.new("слишком много перенаправлений") if redirects > MAX_REDIRECTS

        # Every hop is checked again: a public host may redirect to localhost.
        uri = Import::UrlGuard.check(uri.resolve(location).to_s)
      when 429, 500, 502, 503, 504
        raise Import::Unavailable.new("сайт ответил #{response.status}")
      else
        raise Import::Failed.new("сайт ответил #{response.status}")
      end
    end
  end

  private def self.headers(accept : String) : HTTP::Headers
    HTTP::Headers{
      "User-Agent"      => USER_AGENT,
      "Accept"          => accept,
      "Accept-Language" => "ru,en;q=0.8",
      # Explicit identity stops the client from asking for gzip and decoding it
      # behind our back: what we measure is what the server sent.
      "Accept-Encoding" => "identity",
    }
  end

  # Asking for no compression is what keeps the body readable: the client does
  # not decompress, so a server that gzips anyway would hand us garbage.
  private def self.check_encoding!(headers : HTTP::Headers) : Nil
    encoding = headers["Content-Encoding"]?.to_s.strip.downcase
    return if encoding.empty? || encoding == "identity"

    raise Import::Failed.new("сайт отдал сжатый ответ (#{encoding})")
  end

  private def self.describe(content_type : String) : String
    content_type.empty? ? "файл без типа" : content_type.split(';').first.strip
  end
end
