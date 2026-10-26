module Api::V1::Messages::Lookup
  # The other side of a conversation. Unknown nicknames are a 404, like any
  # other missing record, so a profile cannot be probed through this route.
  def find_peer!(username : String) : User
    UserQuery.new.by_username(username).first? ||
      raise Avram::RecordNotFoundError.new(User.table_name, username)
  end

  def require_other_user!(peer : User) : Nil
    if peer.id == current_user.id
      raise Avram::RecordNotFoundError.new(User.table_name, peer.username)
    end
  end
end
