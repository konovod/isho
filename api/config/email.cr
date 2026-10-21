require "carbon_sendgrid_adapter"

BaseEmail.configure do |settings|
  settings.adapter = mail_adapter
end

# `MAIL_ADAPTER` picks the transport:
#
#   smtp      – any SMTP provider (mail.ru, Yandex, Brevo, Unisender Go, ...)
#   sendgrid  – SendGrid HTTP API, needs SEND_GRID_KEY
#   dev       – prints letters to the log instead of sending (default)
#
private def mail_adapter : Carbon::Adapter
  # Specs never send real letters, whatever .env says.
  return Carbon::DevAdapter.new if LuckyEnv.test?

  case ENV["MAIL_ADAPTER"]?.try(&.strip.downcase)
  when "smtp"
    SmtpMailAdapter.new(
      host: ENV.fetch("SMTP_HOST", "localhost"),
      port: ENV.fetch("SMTP_PORT", "465").to_i,
      mode: SmtpMailAdapter::Mode.parse(ENV["SMTP_TLS"]?),
      username: ENV["SMTP_USER"]?,
      password: ENV["SMTP_PASSWORD"]?,
      helo_domain: ENV["SMTP_HELO_DOMAIN"]?,
    )
  when "sendgrid"
    Carbon::SendGridAdapter.new(api_key: send_grid_key_from_env)
  else
    Carbon::DevAdapter.new(print_emails: LuckyEnv.development?)
  end
end

private def send_grid_key_from_env
  ENV["SEND_GRID_KEY"]? || raise_missing_key_message
end

private def raise_missing_key_message
  puts "Missing SEND_GRID_KEY. Set the SEND_GRID_KEY env variable to 'unused' if not sending emails, or set the SEND_GRID_KEY ENV var.".colorize.red
  exit(1)
end
