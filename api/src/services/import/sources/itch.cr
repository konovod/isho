# itch.io pages are ordinary HTML with Open Graph tags, so the generic reader
# already gets the title, the description and the gallery. The one thing worth
# adding is the page's own tag strip: it tells the model which words the author
# uses, and the plan still only keeps tags that already exist on isho.
#
# Download links on itch live behind a JavaScript dialog and a per-user nonce,
# so they are never taken from here.
module Import::Sources::Itch
  def self.matches?(host : String) : Bool
    host == "itch.io" || host.ends_with?(".itch.io")
  end

  def self.extract(url : URI, html : String) : Import::Page
    page = Import::Sources::Generic.extract(url, html)
    labels = tag_labels(html)
    return page if labels.empty?

    page.with_text("#{page.text}\nТеги со страницы: #{labels.join(", ")}")
  end

  private def self.tag_labels(html : String) : Array(String)
    seen = Set(String).new
    result = [] of String

    html.scan(/<a\b([^>]*)>(.*?)<\/a>/mi) do |match|
      attributes = match[1]
      href = attributes.match(/\bhref\s*=\s*["']([^"']+)["']/i).try(&.[1]?)
      next unless href
      next unless href.includes?("/tag-") || href.includes?("tag=")

      label = Import::Html.squeeze(Import::Html.unescape(match[2].gsub(/<[^>]+>/, " ")))
      next if label.empty? || label.size > 40
      next unless seen.add?(label.downcase)

      result << label
      break if result.size >= 12
    end

    result
  end
end
