# Specs never talk to a real provider. The fake returns a canned completion
# and records every request body, so the examples can assert what was sent.
class AiFakeBackend < Ai::Transport::Backend
  getter requests = [] of String

  property completion_text = "В Godot 4 веб-сборке нужны заголовки COOP и COEP, иначе SharedArrayBuffer не заработает и экспорт не запустится."
  property model = "deepseek-chat"
  property status = 200
  property error_body = ""

  def post(
    url : String,
    headers : HTTP::Headers,
    body : String,
    timeout : Time::Span,
  ) : {Int32, String}
    requests << body

    unless status == 200
      return {status, error_body.empty? ? %({"error":{"message":"provider is down"}}) : error_body}
    end

    payload = {
      "id"      => "spec-completion",
      "model"   => model,
      "choices" => [
        {
          "index"   => 0,
          "message" => {"role" => "assistant", "content" => completion_text},
        },
      ],
      "usage" => {
        "prompt_tokens"     => 120,
        "completion_tokens" => 30,
      },
    }

    {200, payload.to_json}
  end
end

def ai_fake : AiFakeBackend
  Ai::Transport.backend.as(AiFakeBackend)
end
