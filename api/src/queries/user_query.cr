class UserQuery < User::BaseQuery
  def by_username(username : String)
    username(username)
  end
end
