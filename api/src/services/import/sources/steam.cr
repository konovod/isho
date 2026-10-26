require "json"

# Steam has an official store endpoint that is cheaper and far steadier than
# the page markup: name, short and long description, screenshots and genres in
# one JSON answer. Steam never exposes a downloadable build, so the import only
# fills text, tags hints and screenshots for it.
module Import::Sources::Steam
  HOST = "store.steampowered.com"
  API  = "https://store.steampowered.com/api/appdetails"

  def self.matches?(host : String, url : URI) : Bool
    host == HOST && !app_id(url).nil?
  end

  def self.app_id(url : URI) : String?
    url.path.match(%r{/app/(\d+)}).try(&.[1]?)
  end

  def self.extract(url : URI, html : String) : Import::Page?
    id = app_id(url)
    return nil unless id

    fetched = Import::Fetcher.json("#{API}?appids=#{id}&l=russian")
    entry = JSON.parse(fetched.text)[id]?
    return nil unless entry
    return nil unless entry["success"]?.try(&.as_bool?)

    data = entry["data"]?
    return nil unless data

    name = data["name"]?.try(&.as_s?).to_s.strip
    return nil if name.empty?

    page(url, name, data)
  rescue Import::Failed | JSON::ParseException
    nil
  end

  private def self.page(url : URI, name : String, data : JSON::Any) : Import::Page
    short = data["short_description"]?.try(&.as_s?).to_s.strip
    details = data["detailed_description"]?.try(&.as_s?).to_s

    images = data["screenshots"]?.try(&.as_a?).try(&.compact_map { |shot| shot["path_full"]?.try(&.as_s?) }) || [] of String
    if header = data["header_image"]?.try(&.as_s?)
      images = [header] + images
    end

    text = String.build do |io|
      io << Import::Html.text(details)
      if genres = data["genres"]?.try(&.as_a?)
        labels = genres.compact_map { |genre| genre["description"]?.try(&.as_s?) }
        io << "\nЖанры: " << labels.join(", ") unless labels.empty?
      end
      if developers = data["developers"]?.try(&.as_a?)
        labels = developers.compact_map(&.as_s?)
        io << "\nРазработчик: " << labels.join(", ") unless labels.empty?
      end
      if date = data["release_date"]?.try(&.["date"]?).try(&.as_s?)
        io << "\nДата выхода: " << date unless date.strip.empty?
      end
      platforms = [] of String
      platforms << "Windows" if data["platforms"]?.try(&.["windows"]?).try(&.as_bool?)
      platforms << "macOS" if data["platforms"]?.try(&.["mac"]?).try(&.as_bool?)
      platforms << "Linux" if data["platforms"]?.try(&.["linux"]?).try(&.as_bool?)
      io << "\nПлатформы: " << platforms.join(", ") unless platforms.empty?
    end

    Import::Page.new(
      source_url: url.to_s,
      host: url.host.to_s,
      title: name[0, 200],
      description: short[0, 1_000],
      text: text[0, 20_000],
      images: Import::Html.resolve(images, url),
      # Steam has no public download link; the store page is not a build.
      links: [] of {String, String},
    )
  end
end
