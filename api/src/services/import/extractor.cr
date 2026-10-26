require "uri"

# Picks the reader for a host. A site adapter that comes back empty or with too
# little text gives way to the generic reader: a broken adapter must not break
# an import.
module Import::Extractor
  def self.extract(url : URI, html : String) : Import::Page
    host = url.host.to_s.downcase

    page = begin
      if Import::Sources::Steam.matches?(host, url)
        Import::Sources::Steam.extract(url, html)
      elsif Import::Sources::Itch.matches?(host)
        Import::Sources::Itch.extract(url, html)
      end
    rescue Import::Failed | Import::Unavailable
      nil
    end

    return page if page && !page.thin?

    Import::Sources::Generic.extract(url, html)
  end
end
