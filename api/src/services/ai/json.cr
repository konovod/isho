module Ai::Json
  # Models sometimes wrap JSON in a Markdown fence or add a sentence before it.
  # Everything between the first "{" and the last "}" is the object we asked
  # for; anything else means the answer is unusable.
  def self.object(text : String) : JSON::Any?
    cleaned = text.strip
    first = cleaned.index('{')
    last = cleaned.rindex('}')
    return nil if first.nil? || last.nil? || last < first

    JSON.parse(cleaned[first..last])
  rescue JSON::ParseException
    nil
  end
end
