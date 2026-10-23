# Removes an AI flair that turned out rude or simply wrong. The generation time
# is moved to now, so the worker does not rebuild it on the next tick.
#
#   ./bin/tasks ai.clear_flair ivan
class Ai::ClearFlairTask < LuckyTask::Task
  name "ai.clear_flair"
  summary "Clear a user's AI flair by email or username"

  positional_arg identifier, "Email or username of an existing user"

  def call
    user = UserQuery.new.email(identifier).first? ||
           UserQuery.new.by_username(identifier).first?
    raise "User #{identifier} not found" unless user

    SaveUserAiFlair.update!(user, ai_flair: nil, ai_flair_at: Time.utc)
    puts "#{user.username}: AI flair cleared"
  end
end
