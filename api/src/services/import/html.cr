require "json"
require "uri"

# Just enough HTML to read a game page: meta tags, links, images, JSON-LD and
# visible text. There is no HTML parser in the standard library, and pulling a
# C binding for one page shape is not worth it; the shapes below are stable
# enough for meta tags, and a source that stops working simply falls back to the
# generic reader.
module Import::Html
  IMAGE_EXTENSIONS  = %w[.png .jpg .jpeg .webp]
  SOURCE_ATTRIBUTES = %w[src data-src data-lazy_src data-original data-lazy]
  ENTITIES          = {
    "amp"    => "&",
    "lt"     => "<",
    "gt"     => ">",
    "quot"   => "\"",
    "apos"   => "'",
    "nbsp"   => " ",
    "mdash"  => "—",
    "ndash"  => "–",
    "laquo"  => "«",
    "raquo"  => "»",
    "hellip" => "…",
    "rsquo"  => "’",
    "lsquo"  => "‘",
    "ldquo"  => "“",
    "rdquo"  => "”",
  }

  # Lowercase `property`/`name` => content, first value wins.
  def self.metas(html : String) : Hash(String, String)
    result = {} of String => String

    html.scan(/<meta\b[^>]*>/mi) do |match|
      key = attribute(match[0], "property") || attribute(match[0], "name")
      content = attribute(match[0], "content")
      next if key.nil? || content.nil?

      result[key.downcase] ||= unescape(content).strip
    end

    result
  end

  def self.title_tag(html : String) : String
    if match = html.match(/<title\b[^>]*>(.*?)<\/title>/mi)
      squeeze(unescape(match[1]))
    else
      ""
    end
  end

  # Absolute http(s) image addresses, in page order, without duplicates. Both
  # `<img>` previews and links that point at a full-size picture are collected:
  # galleries often keep the original in `href` next to a small preview.
  def self.images(html : String, base : URI) : Array(String)
    found = [] of String

    html.scan(/<img\b[^>]*>/mi) do |match|
      SOURCE_ATTRIBUTES.each do |name|
        value = attribute(match[0], name)
        found << value if value
      end
    end

    html.scan(/<a\b[^>]*>/mi) do |match|
      href = attribute(match[0], "href")
      found << href if href && image_path?(href)
    end

    resolve(found, base)
  end

  def self.links(html : String, base : URI) : Array({String, String})
    seen = Set(String).new
    result = [] of {String, String}

    html.scan(/<a\b([^>]*)>(.*?)<\/a>/mi) do |match|
      href = attribute(match[1], "href")
      next unless href

      href = href.strip
      next if href.empty? || href.starts_with?('#')
      next if href.downcase.starts_with?("javascript:") || href.downcase.starts_with?("data:")

      uri = begin
        base.resolve(href)
      rescue URI::Error
        next
      end

      next unless %w[http https].includes?(uri.scheme.to_s.downcase)

      key = uri.to_s
      next if seen.includes?(key)

      seen << key
      label = squeeze(unescape(match[2].gsub(/<[^>]+>/, " ")))
      result << {key, label[0, 200]}
    end

    result
  end

  # Every `application/ld+json` object on the page, flattened one level.
  def self.json_ld(html : String) : Array(JSON::Any)
    blocks = [] of JSON::Any

    html.scan(/<script\b[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>(.*?)<\/script>/mi) do |match|
      parsed = begin
        JSON.parse(unescape(match[1].strip))
      rescue JSON::ParseException
        next
      end

      if array = parsed.as_a?
        array.each { |item| blocks << item }
      else
        blocks << parsed
      end
    end

    blocks
  end

  # Visible text with scripts, styles and tags removed. Newlines are kept where
  # a block ends, so headings do not glue to the next paragraph in the prompt.
  def self.text(html : String) : String
    body = html
      .gsub(/<script\b[^>]*>.*?<\/script>/mi, " ")
      .gsub(/<style\b[^>]*>.*?<\/style>/mi, " ")
      .gsub(/<noscript\b[^>]*>.*?<\/noscript>/mi, " ")
      .gsub(/<svg\b[^>]*>.*?<\/svg>/mi, " ")
      .gsub(/<!--.*?-->/m, " ")
      .gsub(/<(br|hr)\s*\/?>/mi, "\n")
      .gsub(/<\/(p|div|li|h[1-6]|tr|section|article)>/mi, "\n")
      .gsub(/<[^>]+>/, " ")

    squeeze(unescape(body))
  end

  def self.unescape(value : String) : String
    return value unless value.includes?('&')

    value.gsub(/&(#x?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);/) do
      code = $1
      decoded = if code.starts_with?('#')
                  number = code.lchop('#')
                  if number.starts_with?('x') || number.starts_with?('X')
                    number[1..]?.try(&.to_i?(16)).try { |value| char(value) }
                  else
                    number.to_i?.try { |value| char(value) }
                  end
                else
                  ENTITIES[code.downcase]?
                end

      decoded || "&#{code};"
    end
  end

  def self.resolve(raw : Array(String), base : URI) : Array(String)
    seen = Set(String).new
    result = [] of String

    raw.each do |value|
      value = value.strip
      next if value.empty? || value.starts_with?("data:")

      uri = begin
        base.resolve(value)
      rescue URI::Error
        next
      end

      next unless %w[http https].includes?(uri.scheme.to_s.downcase)
      next unless uri.host

      key = uri.to_s
      next if seen.includes?(key)

      seen << key
      result << key
    end

    result
  end

  def self.squeeze(value : String) : String
    value
      .gsub(/[ \t\f\v\x{A0}]+/, " ")
      .gsub(/ *\n */, "\n")
      .gsub(/\n{2,}/, "\n")
      .strip
  end

  private def self.attribute(tag : String, name : String) : String?
    match = tag.match(/\b#{name}\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))/i)
    return nil unless match

    match[1]? || match[2]? || match[3]?
  end

  private def self.char(value : Int32) : String?
    value.chr.to_s
  rescue
    nil
  end

  private def self.image_path?(href : String) : Bool
    path = href.split('?').first.downcase
    IMAGE_EXTENSIONS.any? { |extension| path.ends_with?(extension) }
  end
end
