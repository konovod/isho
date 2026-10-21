class UserQuery < User::BaseQuery
  def by_username(username : String)
    username(username)
  end

  # Sign-in accepts either an email or a username. Usernames are lowercase
  # and cannot contain "@", so the two can never both match.
  def by_login(login : String)
    email(login).or(&.username(login))
  end

  def search(term : String)
    pattern = "%#{term}%"

    username.ilike(pattern)
      .or(&.email.ilike(pattern))
      .or(&.display_name.ilike(pattern))
  end
end
