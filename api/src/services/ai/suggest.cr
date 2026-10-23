require "digest/sha256"

# Suggests a section for a topic before it is created. One small JSON call,
# cached for ten minutes by the exact title and body so a double click does not
# spend tokens twice.
module Ai::Suggest
  record Suggestion, section : ForumSection, confidence : Float64, reason : String

  # The author is waiting on the form, so this call gets a shorter deadline
  # than a background job.
  TIMEOUT = 8.seconds

  def self.call(user : User, section : ForumSection, title : String, body : String) : Suggestion?
    return nil unless Ai.enabled?

    clean_title = title.strip
    return nil if clean_title.empty?

    clean_body = body.strip[0, AppSettings::AI_SUGGESTION_MAX_INPUT_CHARS]
    key = "ai:section-suggestion:#{Digest::SHA256.hexdigest("#{section.slug}\n#{clean_title}\n#{clean_body}")}"

    # Only successful answers are cached: a provider outage or a rate limit
    # must not freeze the form for ten minutes.
    if cached = LuckyCache.settings.storage.read(key).try(&.value.as?(String))
      return parse(cached, section)
    end

    raw = generate(user, section, clean_title, clean_body)
    return nil unless raw

    LuckyCache.settings.storage.write(key, expires_in: 10.minutes) { raw }
    parse(raw, section)
  end

  private def self.generate(
    user : User,
    current : ForumSection,
    title : String,
    body : String,
  ) : String?
    return nil unless Ai::Quota.consume(user, "topic_suggestion", AppSettings::AI_SUGGESTIONS_PER_DAY)

    sections = ForumSectionQuery.new.position.asc_order.results.reject { |item| item.slug == "projects" }
    return nil if sections.size < 2

    completion = Ai.complete(
      [
        Ai::Message.new("system", Ai::Prompts::SUGGEST_SYSTEM),
        Ai::Message.new("user", Ai::Prompts.topic_suggestion(sections, current, title, body)),
      ],
      max_tokens: AppSettings::AI_SUGGESTION_MAX_TOKENS,
      temperature: 0.0,
      json_response: true,
      timeout: TIMEOUT,
      retries: 0,
    )

    object = Ai::Json.object(completion.text)
    return nil unless object

    slug = object["slug"]?.try(&.as_s?)
    confidence = object["confidence"]?.try(&.as_f?)
    return nil if slug.nil? || confidence.nil?

    reason = object["reason"]?.try(&.as_s?).to_s.strip
    {slug: slug, confidence: confidence, reason: reason[0, 120]}.to_json
  rescue Ai::Error
    nil
  end

  private def self.parse(raw : String, current : ForumSection) : Suggestion?
    parsed = JSON.parse(raw)
  rescue JSON::ParseException
    nil
  else
    slug = parsed["slug"]?.try(&.as_s?)
    confidence = parsed["confidence"]?.try(&.as_f?)
    return nil if slug.nil? || confidence.nil?
    return nil if confidence.not_nil! < AppSettings::AI_SUGGESTION_MIN_CONFIDENCE

    section = ForumSectionQuery.new.by_slug(slug.not_nil!).first?
    return nil unless section
    return nil if section.id == current.id
    return nil if section.slug == "projects"

    reason = parsed["reason"]?.try(&.as_s?).to_s.strip
    Suggestion.new(section, confidence.not_nil!, reason[0, 120])
  end
end
