require "json"
require "uri"

# The fallback reader: Open Graph, Twitter cards, JSON-LD and the visible text.
# It is also the base for every site adapter.
module Import::Sources::Generic
  GAME_TYPES = %w[
    videogame product softwareapplication game website webapplication
  ]

  def self.extract(url : URI, html : String) : Import::Page
    metas = Import::Html.metas(html)
    data = game_object(Import::Html.json_ld(html))

    title = first_present([
      metas["og:title"]?,
      metas["twitter:title"]?,
      data.try(&.["name"]?).try(&.as_s?),
      Import::Html.title_tag(html),
    ])

    description = first_present([
      metas["og:description"]?,
      metas["description"]?,
      metas["twitter:description"]?,
      data.try(&.["description"]?).try(&.as_s?),
    ])

    images = json_ld_images(data, url)
    if og_image = (metas["og:image"]? || metas["twitter:image"]?)
      images = Import::Html.resolve([og_image], url) + images
    end
    images += Import::Html.images(html, url)

    Import::Page.new(
      source_url: url.to_s,
      host: url.host.to_s,
      title: Import::Html.squeeze(title)[0, 200],
      description: description[0, 1_000],
      text: Import::Html.text(html)[0, 20_000],
      images: unique(images),
      links: Import::Html.links(html, url),
    )
  end

  # A page may describe itself as a game, a product or a piece of software; any
  # of those carries the fields we need.
  def self.game_object(blocks : Array(JSON::Any)) : JSON::Any?
    blocks.find { |block| game_type?(block) }
  end

  private def self.game_type?(block : JSON::Any) : Bool
    hash = block.as_h?
    return false unless hash

    type = hash["@type"]?
    return false unless type

    values = type.as_a? ? type.as_a.compact_map(&.as_s?) : [type.as_s?].compact
    values.any? { |value| GAME_TYPES.includes?(value.downcase) }
  end

  private def self.json_ld_images(object : JSON::Any?, base : URI) : Array(String)
    return [] of String unless object

    value = object.as_h?.try(&.["image"]?)
    return [] of String unless value

    raw = if array = value.as_a?
            array.flat_map { |item| image_value(item) }
          else
            image_value(value)
          end

    Import::Html.resolve(raw, base)
  end

  private def self.image_value(value : JSON::Any) : Array(String)
    if text = value.as_s?
      [text]
    elsif hash = value.as_h?
      url = hash["url"]?.try(&.as_s?) || hash["contentUrl"]?.try(&.as_s?)
      url ? [url] : [] of String
    elsif array = value.as_a?
      array.flat_map { |item| image_value(item) }
    else
      [] of String
    end
  end

  private def self.first_present(values : Array(String?)) : String
    values.each do |value|
      return value.not_nil!.strip unless value.nil? || value.strip.empty?
    end

    ""
  end

  private def self.unique(values : Array(String)) : Array(String)
    seen = Set(String).new
    values.select { |value| seen.add?(value) }
  end
end
