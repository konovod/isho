# Escape hatch for deployments where the mail transport is not configured yet,
# or for helping someone who cannot receive the letter.
class Db::ConfirmEmail < LuckyTask::Task
  summary "Mark a user's email as confirmed by email or username"

  positional_arg identifier, "Email or username of an existing user"

  def call
    user = UserQuery.new.email(identifier).first? ||
           UserQuery.new.by_username(identifier).first?

    raise "User #{identifier} not found" unless user

    ConfirmUserEmail.update!(
      user,
      email_confirmed_at: Time.utc,
      email_confirmation_token_hash: nil,
      email_confirmation_sent_at: nil,
    )

    puts "#{user.username} (#{user.email}) email is confirmed"
  end
end
