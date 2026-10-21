class Db::MakeAdmin < LuckyTask::Task
  summary "Grant moderator rights to a user by email or username"

  positional_arg identifier, "Email or username of an existing user"

  def call
    user = UserQuery.new.email(identifier).first? ||
           UserQuery.new.by_username(identifier).first?

    raise "User #{identifier} not found" unless user

    User::SaveOperation.update!(user, is_admin: true)
    puts "#{user.username} (#{user.email}) is now an admin"
  end
end
