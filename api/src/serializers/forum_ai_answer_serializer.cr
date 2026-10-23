class ForumAiAnswerSerializer < BaseSerializer
  def initialize(@answer : ForumAiAnswer)
  end

  def render
    {
      id:     @answer.id,
      status: @answer.status,
      # The body is only handed out when the answer is ready; while the job is
      # queued the page shows a placeholder instead.
      body:       @answer.ready? ? @answer.body : nil,
      model:      @answer.ready? ? @answer.model : nil,
      created_at: @answer.created_at,
    }
  end
end
