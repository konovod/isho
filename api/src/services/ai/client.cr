# Thin client for DeepSeek's OpenAI-compatible chat completions API.
#
# The client is deliberately small: no streaming, two attempts at most, a hard
# timeout and a token budget per call. Every feature that uses it stays off
# when AI_API_KEY is missing, so the forum works as before without secrets.
module Ai
  class Error < Exception; end

  # Network problems, 5xx and 429. The call may succeed later.
  class Unavailable < Error; end

  # Bad key, bad request or a response we cannot parse. Retrying will not help.
  class Rejected < Error; end

  record Message, role : String, content : String
  record Usage, prompt_tokens : Int32, completion_tokens : Int32
  record Completion, text : String, model : String, usage : Usage

  def self.enabled? : Bool
    AppSettings.ai_enabled?
  end

  def self.complete(
    messages : Array(Message),
    max_tokens : Int32,
    temperature : Float64 = 0.7,
    json_response : Bool = false,
    timeout : Time::Span = AppSettings.ai_quick_timeout,
    retries : Int32 = 1,
  ) : Completion
    raise Unavailable.new("AI is not configured") unless enabled?

    payload = build_payload(messages, max_tokens, temperature, json_response)
    url = "#{AppSettings.ai_base_url}/chat/completions"
    headers = HTTP::Headers{
      "Content-Type"  => "application/json",
      "Accept"        => "application/json",
      "Authorization" => "Bearer #{AppSettings.ai_api_key}",
    }

    attempt = 0
    loop do
      attempt += 1

      begin
        status, body = Transport.backend.post(url, headers, payload, timeout)
      rescue ex : Ai::Error
        raise ex
      rescue ex
        if attempt <= retries
          sleep(AppSettings.ai_retry_delay)
          next
        end

        raise Unavailable.new("AI request failed: #{ex.class}: #{ex.message}")
      end

      case status
      when 200
        return parse_completion(body)
      when 429, 500, 502, 503, 504
        if attempt <= retries
          sleep(AppSettings.ai_retry_delay)
          next
        end

        raise Unavailable.new("AI answered #{status}")
      else
        raise Rejected.new("AI rejected the request (#{status}): #{body[0, 300]}")
      end
    end
  end

  private def self.build_payload(
    messages : Array(Message),
    max_tokens : Int32,
    temperature : Float64,
    json_response : Bool,
  ) : String
    JSON.build do |json|
      json.object do
        json.field "model", AppSettings.ai_model
        json.field "messages" do
          json.array do
            messages.each do |message|
              json.object do
                json.field "role", message.role
                json.field "content", message.content
              end
            end
          end
        end
        json.field "max_tokens", max_tokens
        json.field "temperature", temperature
        json.field "stream", false
        if json_response
          json.field "response_format" do
            json.object { json.field "type", "json_object" }
          end
        end
      end
    end
  end

  private def self.parse_completion(body : String) : Completion
    parsed = JSON.parse(body)
  rescue ex : JSON::ParseException
    raise Rejected.new("AI returned malformed JSON")
  else
    text = parsed.dig?("choices", 0, "message", "content").try(&.as_s?)
    if text.nil? || text.strip.empty?
      raise Rejected.new("AI returned no content")
    end

    usage = parsed["usage"]?
    prompt_tokens = usage.try(&.["prompt_tokens"]?).try(&.as_i?) || 0
    completion_tokens = usage.try(&.["completion_tokens"]?).try(&.as_i?) || 0
    model = parsed["model"]?.try(&.as_s?) || AppSettings.ai_model

    Completion.new(
      text: text.not_nil!,
      model: model,
      usage: Usage.new(prompt_tokens: prompt_tokens, completion_tokens: completion_tokens),
    )
  end
end
