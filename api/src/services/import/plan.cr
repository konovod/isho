# Turns the model's JSON into values the ordinary operations accept. Everything
# here is a rejection rule: a missing field falls back to the page, a value the
# model invented is dropped, and a download link must be one the page actually
# linked to.
module Import::Plan
  record Draft,
    title : String,
    tagline : String?,
    description : String?,
    kind : String,
    dev_status : String,
    genre : String?,
    nsfw : Bool,
    tags : Array(String),
    image_urls : Array(String),
    download_url : String?,
    download_label : String?,
    download_platform : String?

  MAX_TAGS        =      8
  TAG_NAME_LENGTH =     40
  MAX_DESCRIPTION = 20_000
  MIN_DESCRIPTION =    200

  def self.from(object : JSON::Any?, page : Import::Page, existing : Array(Tag)) : Draft?
    hash = object.try(&.as_h?)
    return nil unless hash

    confidence = hash["confidence"]?.try(&.as_f?) || 0.0
    return nil if confidence < AppSettings::IMPORT_MIN_CONFIDENCE

    title = title(hash["title"]?.try(&.as_s?), page)
    return nil if title.size < 3

    kind = pick(hash["kind"]?.try(&.as_s?), AppSettings::PROJECT_KINDS, "game")
    dev_status = pick(hash["dev_status"]?.try(&.as_s?), AppSettings::PROJECT_DEV_STATUSES, "active")
    genre = kind == "game" ? pick_or_nil(hash["genre"]?.try(&.as_s?), AppSettings::PROJECT_GENRES) : nil

    download = download(hash["download_url"]?, page)

    Draft.new(
      title: title,
      tagline: text(hash["tagline"]?.try(&.as_s?), 160),
      description: description(hash["description"]?.try(&.as_s?)),
      kind: kind,
      dev_status: dev_status,
      genre: genre,
      nsfw: hash["nsfw"]?.try(&.as_bool?) || false,
      tags: tags(hash["tags"]?, existing),
      image_urls: image_urls(hash["screenshot_indexes"]?, page),
      download_url: download.try(&.[0]),
      download_label: download.try(&.[1]),
      download_platform: download.try(&.[2]),
    )
  end

  private def self.title(value : String?, page : Import::Page) : String
    candidate = value.to_s.strip.gsub(/\s+/, " ")
    candidate = page.title.strip if candidate.empty?
    candidate = candidate.gsub(/\A["'«»]+|["'«»]+\z/, "").strip
    candidate[0, 120]
  end

  private def self.text(value : String?, limit : Int32) : String?
    candidate = value.to_s.strip.gsub(/\s+/, " ")
    return nil if candidate.empty?
    return nil if candidate.size > limit * 2

    candidate[0, limit].strip.presence
  end

  private def self.description(value : String?) : String?
    return nil unless value

    text = Ai::Sanitize.markdown(value)
    # A generated description must not carry links or images: the page can plant
    # them, and the field is shown to every visitor.
    text = text.gsub(/!\[[^\]]*\]\([^)]*\)/, "")
    text = text.gsub(/\[([^\]]*)\]\([^)]*\)/) { $1 }
    text = text.gsub(%r{https?://\S+}, "")
    text = text.gsub(/[ \t]+/, " ").gsub(/\n{3,}/, "\n\n").strip

    return nil if text.gsub(/\s+/, "").size < MIN_DESCRIPTION

    text[0, MAX_DESCRIPTION]
  end

  private def self.tags(value : JSON::Any?, existing : Array(Tag)) : Array(String)
    raw = value.try(&.as_a?) || [] of JSON::Any

    by_name = {} of String => Tag
    by_slug = {} of String => Tag
    existing.each do |tag|
      by_name[tag.name.downcase] = tag
      by_slug[tag.slug] = tag
    end

    seen = Set(Int64).new
    result = [] of String

    raw.each do |item|
      name = item.as_s?.to_s.strip[0, TAG_NAME_LENGTH].strip
      next if name.empty?

      slug = Slugify.call(name, "")
      next if slug.empty?

      tag = by_name[name.downcase]? || by_slug[slug]?
      next unless tag
      next unless seen.add?(tag.id)

      result << tag.name
      break if result.size >= MAX_TAGS
    end

    result
  end

  private def self.image_urls(value : JSON::Any?, page : Import::Page) : Array(String)
    raw = value.try(&.as_a?) || [] of JSON::Any
    seen = Set(Int32).new
    result = [] of String

    raw.each do |item|
      index = item.as_i?
      next unless index
      next if index < 0 || index >= page.images.size
      next unless seen.add?(index)

      result << page.images[index]
      break if result.size >= AppSettings::IMPORT_MAX_IMAGES
    end

    result
  end

  # Only a link the page itself contains becomes a Download, and only if it
  # looks like a build file over https. A link the model made up is dropped.
  private def self.download(value : JSON::Any?, page : Import::Page) : Tuple(String, String, String?)?
    url = value.try(&.as_s?).to_s.strip
    return nil if url.empty?

    candidate = page.links.find { |(href, _)| href == url }
    return nil unless candidate
    return nil unless build_file?(url)

    uri = Import::UrlGuard.check(url)
    return nil unless uri.scheme == "https"

    {url, label_for(candidate[1], url), platform_for(url)}
  rescue Import::UrlGuard::Blocked
    nil
  end

  private def self.build_file?(url : String) : Bool
    path = url.split('?').first.downcase
    AppSettings::IMPORT_FILE_EXTENSIONS.any? { |extension| path.ends_with?(extension) }
  end

  private def self.label_for(label : String, url : String) : String
    candidate = label.strip.gsub(/\s+/, " ")
    return candidate[0, 80] if candidate.size >= 2 && candidate.size <= 80

    url.split('?').first.split('/').last?.to_s[0, 80]
  end

  private def self.platform_for(url : String) : String?
    path = url.split('?').first.downcase
    return "Windows" if path.ends_with?(".exe") || path.ends_with?(".msi")
    return "Android" if path.ends_with?(".apk")
    return "macOS" if path.ends_with?(".dmg")

    nil
  end

  private def self.pick(value : String?, allowed : Array(String), fallback : String) : String
    candidate = value.to_s.strip.downcase
    allowed.includes?(candidate) ? candidate : fallback
  end

  private def self.pick_or_nil(value : String?, allowed : Array(String)) : String?
    candidate = value.to_s.strip.downcase
    allowed.includes?(candidate) ? candidate : nil
  end
end
