# Every example starts with a configured key and a fake provider, so the
# results never depend on the developer's environment or the network.
Spec.before_each do
  ENV["AI_API_KEY"] = "spec-key"
  ENV["AI_RETRY_DELAY_MS"] = "1"
  ENV.delete("AI_DAILY_JOBS")
  ENV.delete("AI_DAILY_INPUT_TOKENS")
  ENV.delete("AI_DAILY_OUTPUT_TOKENS")
  Ai::Transport.backend = AiFakeBackend.new
end
