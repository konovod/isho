require "carbon"
require "email"

# Carbon adapter over the `email` shard. `carbon_smtp_adapter` only speaks
# STARTTLS, while mail.ru (and most providers) expect implicit TLS on port 465,
# so the mode is configurable: `ssl` (SMTPS), `starttls` or `none`.
class SmtpMailAdapter < Carbon::Adapter
  enum Mode
    Smtps
    Starttls
    None

    def self.parse(value : String?) : Mode
      case value.to_s.strip.downcase
      when "starttls"      then Starttls
      when "none", "plain" then None
      else                      Smtps
      end
    end

    def tls_mode : EMail::Client::TLSMode
      case self
      when Mode::Smtps    then EMail::Client::TLSMode::SMTPS
      when Mode::Starttls then EMail::Client::TLSMode::STARTTLS
      else                     EMail::Client::TLSMode::NONE
      end
    end
  end

  def initialize(
    @host : String,
    @port : Int32,
    @mode : Mode = Mode::Smtps,
    @username : String? = nil,
    @password : String? = nil,
    @helo_domain : String? = nil,
  )
  end

  def deliver_now(email : Carbon::Email) : Nil
    EMail.send(
      @host,
      @port,
      helo_domain: @helo_domain || @host,
      auth: auth,
      use_tls: @mode.tls_mode,
    ) do
      subject email.subject

      from(email.from.address, email.from.name)

      email.to.each { |address| to(address.address, address.name) }
      email.cc.each { |address| cc(address.address, address.name) }
      email.bcc.each { |address| bcc(address.address, address.name) }

      email.headers.each do |key, value|
        case key.downcase
        when "reply-to"    then reply_to(value)
        when "message-id"  then message_id(value)
        when "return-path" then return_path(value)
        when "sender"      then sender(value)
        else                    custom_header(key, value)
        end
      end

      if text = email.text_body.presence
        message(text)
      end

      if html = email.html_body.presence
        message_html(html)
      end
    end
  end

  private def auth : Tuple(String, String)?
    username = @username
    password = @password

    if username && password
      {username, password}
    elsif username || password
      raise "SMTP_USER and SMTP_PASSWORD have to be set together"
    end
  end
end
