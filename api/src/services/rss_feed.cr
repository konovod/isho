# Minimal RSS 2.0 document builder. Feeds are assembled by hand instead of a
# template because every value comes from user content and must be escaped, and
# because invalid XML characters have to be dropped before they break a reader.
struct RssFeed
  struct Item
    getter title : String
    getter link : String
    getter guid : String
    getter published_at : Time
    getter creator : String?
    getter description : String?
    getter categories : Array(String)

    def initialize(
      @title : String,
      @link : String,
      @guid : String,
      @published_at : Time,
      @creator : String? = nil,
      @description : String? = nil,
      @categories : Array(String) = [] of String,
    )
    end
  end

  def initialize(
    @title : String,
    @link : String,
    @description : String,
    @self_url : String,
    @items : Array(Item),
  )
  end

  def to_xml : String
    String.build do |io|
      io << %(<?xml version="1.0" encoding="UTF-8"?>\n)
      io << %(<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/elements/1.1/">\n)
      io << "  <channel>\n"
      element(io, "title", @title, 4)
      element(io, "link", @link, 4)
      element(io, "description", @description, 4)
      element(io, "language", "ru", 4)
      element(io, "ttl", "5", 4)
      io << %(    <atom:link href="#{RssFeed.escape(@self_url)}" rel="self" type="application/rss+xml"/>\n)

      if latest = @items.max_by?(&.published_at)
        element(io, "lastBuildDate", RssFeed.rfc822(latest.published_at), 4)
      end

      @items.each do |item|
        io << "    <item>\n"
        element(io, "title", item.title, 6)
        element(io, "link", item.link, 6)
        element(io, "guid", item.guid, 6, %( isPermaLink="false"))
        element(io, "pubDate", RssFeed.rfc822(item.published_at), 6)
        item.creator.try { |creator| element(io, "dc:creator", creator, 6) }
        item.description.try { |description| element(io, "description", description, 6) }
        item.categories.each { |category| element(io, "category", category, 6) }
        io << "    </item>\n"
      end

      io << "  </channel>\n"
      io << "</rss>\n"
    end
  end

  def self.rfc822(time : Time) : String
    time.to_utc.to_s("%a, %d %b %Y %H:%M:%S +0000")
  end

  # XML 1.0 only allows tab, line feed, carriage return and the printable
  # ranges. Postgres stores UTF-8, but user text can still contain C0 controls.
  def self.escape(value : String) : String
    String.build do |io|
      value.each_char do |char|
        code = char.ord

        case char
        when '&'
          io << "&amp;"
        when '<'
          io << "&lt;"
        when '>'
          io << "&gt;"
        when '"'
          io << "&quot;"
        when '\''
          io << "&apos;"
        else
          io << char if valid_xml_char?(code)
        end
      end
    end
  end

  def self.valid_xml_char?(code : Int32) : Bool
    code == 0x09 ||
      code == 0x0A ||
      code == 0x0D ||
      (0x20..0xD7FF).includes?(code) ||
      (0xE000..0xFFFD).includes?(code) ||
      (0x10000..0x10FFFF).includes?(code)
  end

  private def element(io : IO, name : String, value : String, indent : Int32, attributes : String = "") : Nil
    io << " " * indent
    io << '<' << name << attributes << '>'
    io << RssFeed.escape(value)
    io << "</" << name << ">\n"
  end
end
