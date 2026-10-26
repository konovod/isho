module Api::V1::Users::Lookup
  # Unknown nicknames are a 404, like any other missing record.
  def find_user!(username : String) : User
    UserQuery.new.by_username(username).first? ||
      raise Avram::RecordNotFoundError.new(User.table_name, username)
  end
end
