class ForumAiAnswerFactory < Avram::Factory
  def initialize
    topic_id ForumTopicFactory.create.id
    body "Ответ ИИ, достаточно длинный для показа под спойлером."
    model "deepseek-chat"
    status "ready"
    prompt_tokens 0
    completion_tokens 0
  end
end
