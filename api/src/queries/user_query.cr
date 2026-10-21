class UserQuery < User::BaseQuery
  def by_username(username : String)
    username(username)
  end

  def search(term : String)
    pattern = "%#{term}%"

    username.ilike(pattern)
      .or(&.email.ilike(pattern))
      .or(&.display_name.ilike(pattern))
  end
end
