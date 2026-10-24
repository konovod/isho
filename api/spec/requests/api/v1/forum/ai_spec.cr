require "../../../../spec_helper"

private def ai_eligible_user : User
  user = UserFactory.create &.created_at(5.days.ago)
  5.times { ForumPostFactory.create &.user_id(user.id) }
  user
end

private def ai_topic_body : String
  "Собрал прототип на Godot 4.4 и хочу выложить его в браузер. Экспорт в веб весит восемь мегабайт, но грузится быстро."
end

private def ai_create_topic(client : ApiClient, section_slug : String, title : String, body : String, answer = true)
  client.post("/api/v1/forum/sections/#{section_slug}/topics", forum_topic: {
    title:             title,
    body:              body,
    request_ai_answer: answer ? "true" : "false",
  })
end

describe "AI on the forum" do
  describe "answer in a new topic" do
    it "queues an answer and shows it under the first post after the worker runs" do
      user = ai_eligible_user
      ForumSectionFactory.create &.slug("general")

      response = ai_create_topic(AuthHelper.client_for(user), "general", "Как экспортировать Godot в веб?", ai_topic_body)

      response.status_code.should eq 201
      created = JSON.parse(response.body)
      created["ai_answer"]["status"].as_s.should eq "queued"
      created["replies_count"].as_i.should eq 0
      AiJobQuery.new.queued.select_count.should eq 1

      Ai::Worker.process_one.should be_true

      topic = JSON.parse(ApiClient.new.get("/api/v1/forum/sections/general/topics/#{created["slug"].as_s}").body)["topic"]
      topic["ai_answer"]["status"].as_s.should eq "ready"
      topic["ai_answer"]["model"].as_s.should eq "deepseek-chat"
      topic["ai_answer"]["body"].as_s.should contain "COOP"

      # The answer is not a post: counters and "last posted by" stay human.
      topic["replies_count"].as_i.should eq 0
      topic["last_post_author"]["id"].as_i.should eq user.id
      ForumPostQuery.new.for_topic(topic["id"].as_i64).select_count.should eq 1
    end

    it "creates the topic even when the provider rejects the call" do
      user = ai_eligible_user
      ForumSectionFactory.create &.slug("general")
      ai_fake.status = 401

      response = ai_create_topic(AuthHelper.client_for(user), "general", "Тема без ответа", ai_topic_body)

      response.status_code.should eq 201
      created = JSON.parse(response.body)
      created["ai_answer"]["status"].as_s.should eq "queued"

      Ai::Worker.process_one.should be_true

      answer = ForumAiAnswerQuery.new.for_topic(created["id"].as_i64).first?
      answer.should_not be_nil
      answer.not_nil!.status.should eq "failed"
      AiJobQuery.new.recent_first.first?.not_nil!.status.should eq "failed"
    end

    it "does not answer a fresh account" do
      user = UserFactory.create
      5.times { ForumPostFactory.create &.user_id(user.id) }
      ForumSectionFactory.create &.slug("general")

      response = ai_create_topic(AuthHelper.client_for(user), "general", "Новичок", ai_topic_body)

      response.status_code.should eq 201
      JSON.parse(response.body)["ai_answer"].raw.should be_nil
      AiJobQuery.new.select_count.should eq 0
    end

    it "does not answer when the section has AI answers off" do
      user = ai_eligible_user
      ForumSectionFactory.create &.slug("general").ai_answers_enabled(false)

      response = ai_create_topic(AuthHelper.client_for(user), "general", "Раздел без ИИ", ai_topic_body)

      response.status_code.should eq 201
      JSON.parse(response.body)["ai_answer"].raw.should be_nil
      AiJobQuery.new.select_count.should eq 0
    end

    it "skips a topic that is mostly a code dump" do
      user = ai_eligible_user
      ForumSectionFactory.create &.slug("general")
      body = "```crystal\n#{"puts \"hello\"\n" * 200}```"

      response = ai_create_topic(AuthHelper.client_for(user), "general", "Напишите за меня", body)

      response.status_code.should eq 201
      JSON.parse(response.body)["ai_answer"].raw.should be_nil
      AiJobQuery.new.select_count.should eq 0
    end

    it "allows three answers a day" do
      user = ai_eligible_user
      ForumSectionFactory.create &.slug("general")
      client = AuthHelper.client_for(user)

      3.times do |index|
        response = ai_create_topic(client, "general", "Тема номер #{index + 1}", ai_topic_body)
        JSON.parse(response.body)["ai_answer"]["status"].as_s.should eq "queued"
      end

      fourth = ai_create_topic(client, "general", "Тема номер 4", ai_topic_body)
      JSON.parse(fourth.body)["ai_answer"].raw.should be_nil
      AiJobQuery.new.select_count.should eq 3
      JSON.parse(client.get("/api/v1/me").body)["ai"]["answers_left"].as_i.should eq 0
    end

    it "stops when the server daily budget is used up" do
      ENV["AI_DAILY_JOBS"] = "1"
      user = ai_eligible_user
      ForumSectionFactory.create &.slug("general")
      client = AuthHelper.client_for(user)

      first = ai_create_topic(client, "general", "Первая тема", ai_topic_body)
      JSON.parse(first.body)["ai_answer"]["status"].as_s.should eq "queued"

      second = ai_create_topic(client, "general", "Вторая тема", ai_topic_body)
      JSON.parse(second.body)["ai_answer"].raw.should be_nil
      AiJobQuery.new.select_count.should eq 1
    end

    it "does nothing without an API key" do
      ENV.delete("AI_API_KEY")
      user = ai_eligible_user
      ForumSectionFactory.create &.slug("general")

      response = ai_create_topic(AuthHelper.client_for(user), "general", "Без ключа", ai_topic_body)

      response.status_code.should eq 201
      JSON.parse(response.body)["ai_answer"].raw.should be_nil
      AiJobQuery.new.select_count.should eq 0
    end
  end

  describe "ai answer endpoint" do
    it "returns an empty answer for a topic without one" do
      topic = ForumTopicFactory.create

      response = ApiClient.new.get("/api/v1/forum/topics/#{topic.id}/ai_answer")

      response.status_code.should eq 200
      JSON.parse(response.body)["ai_answer"].raw.should be_nil
    end

    it "lets an admin remove the answer" do
      answer = ForumAiAnswerFactory.create
      ordinary = UserFactory.create

      AuthHelper.client_for(ordinary).delete("/api/v1/forum/topics/#{answer.topic_id}/ai_answer").status_code.should eq 403

      admin = UserFactory.create &.is_admin(true)
      AuthHelper.client_for(admin).delete("/api/v1/forum/topics/#{answer.topic_id}/ai_answer").status_code.should eq 204
      ForumAiAnswerQuery.new.for_topic(answer.topic_id).first?.should be_nil
    end
  end

  describe "section suggestion" do
    it "suggests another section" do
      user = UserFactory.create
      ForumSectionFactory.create &.slug("general").position(0)
      ForumSectionFactory.create &.slug("tech").position(10)
      ai_fake.completion_text = %({"slug":"tech","confidence":0.9,"reason":"Это про технологии"})

      response = AuthHelper.client_for(user).post("/api/v1/forum/topic_suggestions", forum_topic: {
        section_slug: "general",
        title:        "Как выбрать движок",
        body:         "Сравниваю Godot и Unity для маленького проекта.",
      })

      response.status_code.should eq 200
      suggestion = JSON.parse(response.body)["suggestion"]
      suggestion["section"]["slug"].as_s.should eq "tech"
      suggestion["reason"].as_s.should eq "Это про технологии"

      request = JSON.parse(ai_fake.requests.first)
      request["response_format"]["type"].as_s.should eq "json_object"
      request["messages"][1]["content"].as_s.should contain "tech"
      request["messages"][1]["content"].as_s.should_not contain "projects"
    end

    it "says nothing when the topic already fits the current section" do
      user = UserFactory.create
      ForumSectionFactory.create &.slug("general")
      ForumSectionFactory.create &.slug("tech")
      ai_fake.completion_text = %({"slug":"general","confidence":0.95,"reason":"Подходит"})

      response = AuthHelper.client_for(user).post("/api/v1/forum/topic_suggestions", forum_topic: {
        section_slug: "general",
        title:        "Вопрос по форуму",
        body:         "Как прикрепить картинку?",
      })

      JSON.parse(response.body)["suggestion"].raw.should be_nil
    end

    it "ignores a malformed answer and a low confidence" do
      user = UserFactory.create
      ForumSectionFactory.create &.slug("general")
      ForumSectionFactory.create &.slug("tech")
      client = AuthHelper.client_for(user)

      ai_fake.completion_text = "я не умею в json"
      JSON.parse(client.post("/api/v1/forum/topic_suggestions", forum_topic: {
        section_slug: "general", title: "Раз", body: "Первый текст",
      }).body)["suggestion"].raw.should be_nil

      ai_fake.completion_text = %({"slug":"tech","confidence":0.2,"reason":"Слабо"})
      JSON.parse(client.post("/api/v1/forum/topic_suggestions", forum_topic: {
        section_slug: "general", title: "Два", body: "Второй текст",
      }).body)["suggestion"].raw.should be_nil
    end

    it "requires authentication" do
      ForumSectionFactory.create &.slug("general")

      response = ApiClient.new.post("/api/v1/forum/topic_suggestions", forum_topic: {
        section_slug: "general", title: "Тема", body: "Текст",
      })

      response.status_code.should eq 401
    end

    it "limits the number of calls per hour" do
      user = UserFactory.create
      ForumSectionFactory.create &.slug("general")
      ForumSectionFactory.create &.slug("tech")
      ai_fake.completion_text = %({"slug":"tech","confidence":0.9,"reason":"Туда"})
      client = AuthHelper.client_for(user)

      statuses = (1..12).map do |index|
        client.post("/api/v1/forum/topic_suggestions", forum_topic: {
          section_slug: "general",
          title:        "Тема #{index}",
          body:         "Уникальный текст #{index}",
        }).status_code
      end

      statuses.count(429).should eq 1
    end
  end

  describe "section setting" do
    it "lets an admin turn answers off for a section" do
      admin = UserFactory.create &.is_admin(true)
      section = ForumSectionFactory.create &.slug("general")

      response = AuthHelper.client_for(admin).patch("/api/v1/admin/forum/sections/#{section.id}", forum_section: {
        ai_answers_enabled: false,
      })

      response.status_code.should eq 200
      JSON.parse(response.body)["ai_answers_enabled"].as_bool.should be_false
      ForumSectionQuery.new.id(section.id).first?.not_nil!.ai_answers_enabled.should be_false
    end

    it "never enables answers for project discussions" do
      admin = UserFactory.create &.is_admin(true)
      section = ForumSectionFactory.create &.slug("projects").ai_answers_enabled(false)

      response = AuthHelper.client_for(admin).patch("/api/v1/admin/forum/sections/#{section.id}", forum_section: {
        ai_answers_enabled: true,
      })

      response.status_code.should eq 200
      JSON.parse(response.body)["ai_answers_enabled"].as_bool.should be_false
    end
  end

  describe "user flair" do
    it "builds and sanitizes a flair from the latest posts" do
      user = UserFactory.create &.created_at(10.days.ago)
      10.times { ForumPostFactory.create &.user_id(user.id) }
      ai_fake.completion_text = %({"flair":"  \\"Godot-евангелист\\"  "})

      Ai::Flair.schedule.should eq 1
      Ai::Worker.process_one.should be_true

      refreshed = UserQuery.new.id(user.id).first?.not_nil!
      refreshed.ai_flair.should eq "Godot-евангелист"

      # The cooldown keeps the worker from spending on the same account twice.
      Ai::Flair.schedule.should eq 0
    end

    it "does not schedule a flair for an author who turned it off" do
      user = UserFactory.create &.created_at(10.days.ago).ai_flair_enabled(false)
      10.times { ForumPostFactory.create &.user_id(user.id) }

      Ai::Flair.schedule.should eq 0
    end

    it "hides a disabled flair from other users" do
      user = UserFactory.create &.ai_flair_enabled(false)
      SaveUserAiFlair.update!(user, ai_flair: "Скрытая метка", ai_flair_at: Time.utc)

      body = JSON.parse(ApiClient.new.get("/api/v1/users/#{user.username}").body)
      body["user"]["ai_flair"].raw.should be_nil

      SavePreferences.update!(user, ai_flair_enabled: true)
      body = JSON.parse(ApiClient.new.get("/api/v1/users/#{user.username}").body)
      body["user"]["ai_flair"].as_s.should eq "Скрытая метка"
    end

    it "saves the preference from the settings form" do
      user = UserFactory.create

      response = AuthHelper.client_for(user).patch("/api/v1/me/preferences", user: {
        show_nsfw:        true,
        max_ai_usage:     "full",
        ai_flair_enabled: false,
      })

      response.status_code.should eq 200
      JSON.parse(response.body)["ai"]["flair_enabled"].as_bool.should be_false
      UserQuery.new.id(user.id).first?.not_nil!.ai_flair_enabled.should be_false
    end
  end
end
