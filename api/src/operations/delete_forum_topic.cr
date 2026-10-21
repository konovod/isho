class DeleteForumTopic < Avram::Operation
  needs topic : ForumTopic

  def run
    ForumTopic::DeleteOperation.delete!(topic)
  end
end
