# Model output is shown to every visitor, so it is trimmed, flattened and
# stripped of anything that looks like a link or a mention before it is stored.
module Ai::Sanitize
  def self.markdown(text : String) : String
    value = text.strip
    value = value.sub(/\A```[a-zA-Z]*\n?/, "").sub(/\n?```\z/, "")
    value = value.sub(/\A:::spoiler[^\n]*\n?/, "").sub(/\n?:::\s*\z/, "")
    value = value.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, "")
    value = value.gsub(/\r\n?/, "\n")
    value = value.gsub(/\n{3,}/, "\n\n")
    value.strip
  end

  # A flair must fit on one line under a nickname.
  def self.flair(text : String) : String?
    value = text.lines.first?.to_s.strip
    value = value.gsub(/https?:\/\/\S+/i, "")
    value = value.gsub(/www\.\S+/i, "")
    value = value.gsub(/@[A-Za-z0-9_]+/, "")
    value = value.gsub(/[<>`*_~]/, "")
    value = value.gsub(/\A["']+/, "").gsub(/["']+\z/, "")
    value = value.gsub(/\s+/, " ").strip

    return nil if value.size < 3
    return nil if value.downcase.includes?("http")
    return nil if value.downcase.includes?("не могу")
    return nil if value.downcase.includes?("as an ai")
    return nil if value.downcase.includes?("извин")
    return nil if value.downcase.includes?("openai")

    cut(value, AppSettings::AI_FLAIR_MAX_CHARS)
  end

  # Cuts at a word boundary instead of in the middle of a word.
  private def self.cut(value : String, limit : Int32) : String
    return value if value.size <= limit

    head = value[0, limit + 1]
    space = head.rindex(' ')
    space && space > limit // 2 ? head[0, space].strip : value[0, limit].strip
  end
end
