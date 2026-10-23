class DeleteForumAiAnswer < Avram::Operation
  needs answer : ForumAiAnswer

  def run
    ForumAiAnswer::DeleteOperation.delete!(answer)
  end
end
