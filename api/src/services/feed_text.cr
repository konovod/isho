# Turns Markdown into the plain text used by feed previews. The rules mirror
# `markdownToText` in web/app/utils/markdown.ts so a feed excerpt reads the
# same as a catalogue card or a forum snippet.
module FeedText
  EXCERPT_MAX_CHARS = 500

  def self.to_text(source : String?) : String
    return "" if source.nil? || source.empty?

    source
      .gsub(/```[\s\S]*?```/, " ")
      .gsub(/`([^`]*)`/, "\\1")
      .gsub(/!\[[^\]]*\]\([^)]*\)/, " ")
      .gsub(/\[([^\]]*)\]\([^)]*\)/, "\\1")
      .gsub(/^[ \t]*:::[^\n]*$/m, " ")
      .gsub(/^\s{0,3}[#]{1,6}\s+/m, "")
      .gsub(/^\s{0,3}>\s?/m, "")
      .gsub(/^\s*(?:[-*+]|\d+\.)\s+/m, "")
      .gsub(/[*_~]{1,3}([^*_~]+)[*_~]{1,3}/, "\\1")
      .gsub(/<[^>]+>/, " ")
      .gsub(/\s+/, " ")
      .strip
  end

  # Cuts at a word boundary unless that would lose more than half the limit.
  def self.excerpt(source : String?, max : Int32 = EXCERPT_MAX_CHARS) : String
    text = to_text(source)
    return text if text.size <= max

    slice = text[0, max]
    last_space = slice.rindex(' ')

    if last_space && last_space > (max * 3) // 5
      "#{slice[0, last_space].rstrip}…"
    else
      "#{slice.rstrip}…"
    end
  end
end
