require "../../../../spec_helper"

describe Api::V1::Forum do
  describe "GET /api/v1/forum/sections" do
    it "lists sections with topic and post counts" do
      section = ForumSectionFactory.create &.slug("site")
      topic = ForumTopicFactory.create &.section_id(section.id)
      ForumPostFactory.create &.topic_id(topic.id)

      response = ApiClient.new.get("/api/v1/forum/sections")

      response.status_code.should eq 200
      item = JSON.parse(response.body)["items"].as_a.first
      item["slug"].as_s.should eq "site"
      item["topics_count"].as_i.should eq 1
      item["posts_count"].as_i.should eq 1
    end

    it "returns the two-level hierarchy" do
      root = ForumSectionFactory.create &.slug("jams")
      child = ForumSectionFactory.create &.slug("jam-1").parent_id(root.id)

      response = ApiClient.new.get("/api/v1/forum/sections")

      response.status_code.should eq 200
      items = JSON.parse(response.body)["items"].as_a
      root_item = items.find { |item| item["slug"].as_s == root.slug }.not_nil!
      child_item = items.find { |item| item["slug"].as_s == child.slug }.not_nil!

      root_item["parent_id"].as_nil.should be_nil
      root_item["children_count"].as_i.should eq 1
      child_item["parent_id"].as_i64.should eq root.id
      child_item["parent"]["slug"].as_s.should eq root.slug
      child_item["depth"].as_i.should eq 1
    end
  end

  describe "POST /api/v1/forum/sections/:section_slug/topics" do
    it "creates a topic and its first post" do
      user = UserFactory.create
      section = ForumSectionFactory.create &.slug("site")

      response = AuthHelper.client_for(user).post("/api/v1/forum/sections/site/topics", forum_topic: {
        title: "Первая тема",
        body:  "## Привет\n\nТекст темы.",
      })

      response.status_code.should eq 201
      body = JSON.parse(response.body)
      body["slug"].as_s.should eq "pervaya-tema"
      body["replies_count"].as_i.should eq 0

      topic = ForumTopicQuery.new.for_section(section.id).first?
      topic.should_not be_nil
      topic.not_nil!.title.should eq "Первая тема"

      first_post = ForumPostQuery.new.for_topic(topic.not_nil!.id).chronological.first?
      first_post.should_not be_nil
      first_post.not_nil!.body.should eq "## Привет\n\nТекст темы."
      first_post.not_nil!.user_id.should eq user.id
    end

    it "requires authentication" do
      ForumSectionFactory.create &.slug("site")

      response = ApiClient.new.post("/api/v1/forum/sections/site/topics", forum_topic: {
        title: "Аноним",
        body:  "Текст",
      })

      response.status_code.should eq 401
    end

    it "makes slugs unique within the section" do
      user = UserFactory.create
      ForumSectionFactory.create &.slug("site")
      client = AuthHelper.client_for(user)

      first = JSON.parse(client.post("/api/v1/forum/sections/site/topics", forum_topic: {
        title: "Одна тема",
        body:  "Первый текст",
      }).body)
      second = JSON.parse(client.post("/api/v1/forum/sections/site/topics", forum_topic: {
        title: "Одна тема",
        body:  "Второй текст",
      }).body)

      first["slug"].as_s.should eq "odna-tema"
      second["slug"].as_s.should eq "odna-tema-2"
    end
  end

  describe "GET /api/v1/forum/sections/:section_slug" do
    it "lists topics with pagination" do
      section = ForumSectionFactory.create &.slug("site")
      3.times { ForumTopicFactory.create &.section_id(section.id) }

      response = ApiClient.new.get("/api/v1/forum/sections/site?per_page=2")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["items"].as_a.size.should eq 2
      body["meta"]["total"].as_i.should eq 3
      body["meta"]["pages"].as_i.should eq 2
    end

    it "returns subsections above the topics" do
      root = ForumSectionFactory.create &.slug("jams")
      child = ForumSectionFactory.create &.slug("jam-1").parent_id(root.id)

      response = ApiClient.new.get("/api/v1/forum/sections/jams")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["section"]["children_count"].as_i.should eq 1
      body["children"].as_a.map(&.["slug"].as_s).should eq [child.slug]
      body["children"].as_a.first["parent"]["slug"].as_s.should eq root.slug
    end
  end

  describe "GET /api/v1/forum/sections/:section_slug/topics/:topic_slug" do
    it "returns posts in chronological order" do
      section = ForumSectionFactory.create
      topic = ForumTopicFactory.create &.section_id(section.id)
      first = ForumPostFactory.create &.topic_id(topic.id).created_at(Time.utc - 1.hour)
      second = ForumPostFactory.create &.topic_id(topic.id).created_at(Time.utc)

      response = ApiClient.new.get("/api/v1/forum/sections/#{section.slug}/topics/#{topic.slug}")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["topic"]["id"].as_i64.should eq topic.id
      body["items"].as_a.map(&.["id"].as_i64).should eq [first.id, second.id]
    end

    it "includes the parent section in the topic breadcrumb" do
      root = ForumSectionFactory.create &.slug("jams")
      child = ForumSectionFactory.create &.slug("jam-1").parent_id(root.id)
      topic = ForumTopicFactory.create &.section_id(child.id)

      response = ApiClient.new.get("/api/v1/forum/sections/jam-1/topics/#{topic.slug}")

      response.status_code.should eq 200
      section = JSON.parse(response.body)["topic"]["section"]
      section["slug"].as_s.should eq child.slug
      section["parent"]["slug"].as_s.should eq root.slug
    end
  end

  describe "POST /api/v1/forum/topics/:id/posts" do
    it "creates a reply and stores a quote snapshot" do
      user = UserFactory.create
      topic = ForumTopicFactory.create
      quoted = ForumPostFactory.create &.topic_id(topic.id).user_id(user.id).body("Цитируемый текст")

      response = AuthHelper.client_for(user).post("/api/v1/forum/topics/#{topic.id}/posts", forum_post: {
        body:           "Ответ",
        quoted_post_id: quoted.id.to_s,
      })

      response.status_code.should eq 201
      body = JSON.parse(response.body)
      body["quote"]["post_id"].as_i64.should eq quoted.id
      body["quote"]["body"].as_s.should eq "Цитируемый текст"
      body["quote"]["author_name"].as_s.should eq user.name

      forum_topic = ForumTopicQuery.new.id(topic.id).first?.not_nil!
      forum_topic.replies_count.should eq 1
      forum_topic.last_post_at.should be > topic.last_post_at
    end

    it "stores only the selected fragment of a quote" do
      user = UserFactory.create
      topic = ForumTopicFactory.create
      quoted = ForumPostFactory.create &.topic_id(topic.id).user_id(user.id).body("Первый абзац.\n\nЦитируемый кусок текста.")

      response = AuthHelper.client_for(user).post("/api/v1/forum/topics/#{topic.id}/posts", forum_post: {
        body:           "Ответ",
        quoted_post_id: quoted.id.to_s,
        quote_text:     "  Цитируемый кусок текста.  ",
      })

      response.status_code.should eq 201
      body = JSON.parse(response.body)
      body["quote"]["post_id"].as_i64.should eq quoted.id
      body["quote"]["body"].as_s.should eq "Цитируемый кусок текста."
    end

    it "quotes the whole post when the fragment is blank" do
      user = UserFactory.create
      topic = ForumTopicFactory.create
      quoted = ForumPostFactory.create &.topic_id(topic.id).user_id(user.id).body("Весь текст сообщения")

      response = AuthHelper.client_for(user).post("/api/v1/forum/topics/#{topic.id}/posts", forum_post: {
        body:           "Ответ",
        quoted_post_id: quoted.id.to_s,
        quote_text:     "   ",
      })

      response.status_code.should eq 201
      JSON.parse(response.body)["quote"]["body"].as_s.should eq "Весь текст сообщения"
    end

    it "truncates a fragment longer than the quote limit" do
      user = UserFactory.create
      topic = ForumTopicFactory.create
      quoted = ForumPostFactory.create &.topic_id(topic.id).user_id(user.id)

      response = AuthHelper.client_for(user).post("/api/v1/forum/topics/#{topic.id}/posts", forum_post: {
        body:           "Ответ",
        quoted_post_id: quoted.id.to_s,
        quote_text:     "я" * (AppSettings::FORUM_QUOTE_MAX_CHARS + 50),
      })

      response.status_code.should eq 201
      JSON.parse(response.body)["quote"]["body"].as_s.size.should eq AppSettings::FORUM_QUOTE_MAX_CHARS
    end

    it "ignores a fragment without a quoted post" do
      user = UserFactory.create
      topic = ForumTopicFactory.create

      response = AuthHelper.client_for(user).post("/api/v1/forum/topics/#{topic.id}/posts", forum_post: {
        body:       "Ответ",
        quote_text: "Кусок",
      })

      response.status_code.should eq 201
      JSON.parse(response.body)["quote"].as_nil.should be_nil
    end

    it "reports the page of the quoted post" do
      author = UserFactory.create
      section = ForumSectionFactory.create
      topic = ForumTopicFactory.create &.section_id(section.id)
      quoted = ForumPostFactory.create &.topic_id(topic.id).user_id(author.id).created_at(Time.utc - 2.hours)

      (AppSettings::FORUM_POSTS_PER_PAGE - 1).times do |index|
        ForumPostFactory.create &.topic_id(topic.id).created_at(Time.utc - 1.hour + index.seconds)
      end

      client = AuthHelper.client_for(author)
      reply = JSON.parse(client.post("/api/v1/forum/topics/#{topic.id}/posts", forum_post: {
        body:           "Ответ",
        quoted_post_id: quoted.id.to_s,
      }).body)

      reply["quote"]["page"].as_i.should eq 1

      second_page = JSON.parse(
        client.get("/api/v1/forum/sections/#{section.slug}/topics/#{topic.slug}?page=2").body
      )
      second_page["items"].as_a.first["quote"]["page"].as_i.should eq 1
    end

    it "rejects a quote from another topic" do
      user = UserFactory.create
      topic = ForumTopicFactory.create
      other_topic = ForumTopicFactory.create
      other_post = ForumPostFactory.create &.topic_id(other_topic.id)

      response = AuthHelper.client_for(user).post("/api/v1/forum/topics/#{topic.id}/posts", forum_post: {
        body:           "Ответ",
        quoted_post_id: other_post.id.to_s,
      })

      response.status_code.should eq 422
      ForumPostQuery.new.for_topic(topic.id).select_count.should eq 0
    end
  end

  describe "PATCH and DELETE /api/v1/forum/posts/:id" do
    it "lets the author edit, but not delete" do
      author = UserFactory.create
      topic = ForumTopicFactory.create
      post = ForumPostFactory.create &.topic_id(topic.id).user_id(author.id).body("Старый текст")
      client = AuthHelper.client_for(author)

      updated = client.patch("/api/v1/forum/posts/#{post.id}", forum_post: {body: "Новый текст"})
      updated.status_code.should eq 200
      JSON.parse(updated.body)["body"].as_s.should eq "Новый текст"

      client.delete("/api/v1/forum/posts/#{post.id}").status_code.should eq 403
      ForumPostQuery.new.id(post.id).first?.should_not be_nil
    end

    it "does not let a stranger edit" do
      post = ForumPostFactory.create
      stranger = AuthHelper.client_for(UserFactory.create)

      stranger.patch("/api/v1/forum/posts/#{post.id}", forum_post: {body: "Взлом"}).status_code.should eq 403
    end

    it "lets an admin delete a reply and updates counters" do
      admin = UserFactory.create &.is_admin(true)
      topic = ForumTopicFactory.create &.replies_count(1)
      ForumPostFactory.create &.topic_id(topic.id)
      post = ForumPostFactory.create &.topic_id(topic.id)

      response = AuthHelper.client_for(admin).delete("/api/v1/forum/posts/#{post.id}")

      response.status_code.should eq 204
      ForumPostQuery.new.id(post.id).first?.should be_nil
      ForumTopicQuery.new.id(topic.id).first?.not_nil!.replies_count.should eq 0
    end

    it "does not delete the first post of a topic" do
      admin = UserFactory.create &.is_admin(true)
      topic = ForumTopicFactory.create
      first = ForumPostFactory.create &.topic_id(topic.id)

      response = AuthHelper.client_for(admin).delete("/api/v1/forum/posts/#{first.id}")

      response.status_code.should eq 422
      ForumPostQuery.new.id(first.id).first?.should_not be_nil
    end
  end

  describe "DELETE /api/v1/forum/topics/:id" do
    it "lets an admin delete a topic with all posts" do
      admin = UserFactory.create &.is_admin(true)
      topic = ForumTopicFactory.create
      ForumPostFactory.create &.topic_id(topic.id)

      response = AuthHelper.client_for(admin).delete("/api/v1/forum/topics/#{topic.id}")

      response.status_code.should eq 204
      ForumTopicQuery.new.id(topic.id).first?.should be_nil
      ForumPostQuery.new.for_topic(topic.id).select_count.should eq 0
    end
  end
end
