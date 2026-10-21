# Learn about sending emails
# https://luckyframework.org/guides/emails/sending-emails-with-carbon
abstract class BaseEmail < Carbon::Email
  # Every letter goes out from the address configured for the deployment.
  def default_from : Carbon::Address
    Carbon::Address.new(AppSettings.mail_from)
  end
end
