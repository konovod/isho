# Sending is the only way to create a message, so the limit lives on that
# action. Lucky's own `RateLimit` answers with plain text; the API promises
# one JSON error shape, so the counter is kept here instead.
module Api::V1::Messages::RateLimit
  macro included
    before enforce_message_rate_limit
  end

  private def enforce_message_rate_limit
    within = 1.minute
    key = "ratelimit:private_messages:#{current_user.id}"
    cache = LuckyCache.settings.storage
    count = cache.fetch(key, as: Int32, expires_in: within) { 0 }
    cache.write(key, expires_in: within) { count + 1 }

    if count >= AppSettings::PRIVATE_MESSAGES_PER_MINUTE
      json ErrorSerializer.new(
        code: "too_many_requests",
        message: "Слишком много сообщений. Подождите минуту.",
      ), status: 429
    else
      continue
    end
  end
end
