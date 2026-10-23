# The AI opening answer of a topic. It lives in its own table, so it never
# touches reply counters, "last posted by" or unread markers.
module Ai::ForumAnswer
  # A first post that is mostly a code dump is a request for a free coding
  # assistant, not a discussion opener.
  CODE_HEAVY_CHARS = 1_200

  def self.enqueue(topic : ForumTopic, user : User, section : ForumSection) : ForumAiAnswer?
    return nil unless Ai.enabled?
    return nil unless section.ai_answers_enabled
    return nil if section.slug == "projects" || topic.project_id
    return nil if ForumAiAnswerQuery.new.for_topic(topic.id).first?
    return nil unless eligible?(user, topic)
    return nil unless Ai::Quota.consume(user, "forum_answer", AppSettings::AI_FORUM_ANSWERS_PER_DAY)

    answer = nil

    AppDatabase.transaction do
      answer = SaveForumAiAnswer.create!(
        topic_id: topic.id,
        # Non-blank placeholder: Avram rejects empty required strings. The
        # serializer hides the body until the status is "ready".
        body: "Готовим ответ…",
        model: AppSettings.ai_model,
        status: "queued",
        prompt_tokens: 0,
        completion_tokens: 0,
      )

      Ai::Jobs.enqueue("forum_answer", user.id, topic.id)
    end

    answer.not_nil!
  end

  def self.eligible?(user : User, topic : ForumTopic) : Bool
    return false unless user.email_confirmed?
    return false if user.banned?
    return false if user.created_at > AppSettings::AI_ANSWER_MIN_ACCOUNT_AGE.ago
    return false if ForumPostQuery.new.by_user(user.id).select_count < AppSettings::AI_ANSWER_MIN_POSTS

    first_post = ForumPostQuery.new.for_topic(topic.id).chronological.first?
    return false unless first_post
    return false if code_heavy?(first_post.body)

    true
  end

  def self.code_heavy?(body : String) : Bool
    return false if body.size < 400

    code_chars = body.scan(/```.*?```/m).sum { |match| match[0].size }
    code_chars > CODE_HEAVY_CHARS || code_chars * 2 >= body.size
  end

  def self.perform(job : AiJob) : Nil
    topic_id = job.topic_id
    unless topic_id
      Ai::Jobs.skip!(job, "no topic")
      return
    end

    answer = ForumAiAnswerQuery.new.for_topic(topic_id).first?
    unless answer
      Ai::Jobs.skip!(job, "no answer row")
      return
    end

    if answer.status == "ready"
      Ai::Jobs.skip!(job, "already answered")
      return
    end

    topic = ForumTopicQuery.new.id(topic_id).preload_section.first?
    unless topic
      SaveForumAiAnswer.update!(answer, status: "skipped", error: "topic deleted")
      Ai::Jobs.skip!(job, "topic deleted")
      return
    end

    unless topic.section.ai_answers_enabled
      SaveForumAiAnswer.update!(answer, status: "skipped", error: "section disabled")
      Ai::Jobs.skip!(job, "section disabled")
      return
    end

    first_post = ForumPostQuery.new.for_topic(topic_id).chronological.first?
    unless first_post
      SaveForumAiAnswer.update!(answer, status: "skipped", error: "no first post")
      Ai::Jobs.skip!(job, "no first post")
      return
    end

    body = first_post.body.strip[0, AppSettings::AI_ANSWER_MAX_INPUT_CHARS]

    # The opening post can be edited between enqueue and the worker run; a
    # code dump is still not a discussion the bot should answer.
    if code_heavy?(first_post.body)
      SaveForumAiAnswer.update!(answer, status: "skipped", error: "code-heavy topic")
      Ai::Jobs.skip!(job, "code-heavy topic")
      return
    end

    completion = Ai.complete(
      [
        Ai::Message.new("system", Ai::Prompts::ANSWER_SYSTEM),
        Ai::Message.new("user", Ai::Prompts.forum_answer(topic.section.title, topic.title, body)),
      ],
      max_tokens: AppSettings::AI_ANSWER_MAX_TOKENS,
      temperature: 0.7,
      timeout: AppSettings.ai_answer_timeout,
    )

    usage = completion.usage
    text = Ai::Sanitize.markdown(completion.text)

    if text.size < 40
      SaveForumAiAnswer.update!(
        answer,
        status: "skipped",
        error: "answer too short",
        prompt_tokens: usage.prompt_tokens,
        completion_tokens: usage.completion_tokens,
      )
      Ai::Jobs.skip!(job, "answer too short", usage.prompt_tokens, usage.completion_tokens)
      return
    end

    SaveForumAiAnswer.update!(
      answer,
      body: text[0, AppSettings::AI_ANSWER_MAX_CHARS],
      model: completion.model,
      status: "ready",
      error: nil,
      prompt_tokens: usage.prompt_tokens,
      completion_tokens: usage.completion_tokens,
    )
    Ai::Jobs.complete!(job, usage.prompt_tokens, usage.completion_tokens)
  rescue ex : Ai::Error
    if answer
      SaveForumAiAnswer.update!(answer, status: "failed", error: ex.message.to_s[0, 500])
    end
    Ai::Jobs.fail!(job, ex.message.to_s)
  end
end
