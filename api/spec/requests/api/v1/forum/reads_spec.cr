require "../../../../spec_helper"

describe "Forum read tracking" do
  describe "GET /api/v1/forum/sections" do
    it "does not expose unread counters to visitors" do
      section = ForumSectionFactory.create &.slug("site")
      ForumTopicFactory.create &.section_id(section.id)

      response = ApiClient.new.get("/api/v1/forum/sections")

      response.status_code.should eq 200
      JSON.parse(response.body)["items"].as_a.first["unread_topics_count"].as_i.should eq 0
    end

    it "counts unread topics for a signed-in user" do
      user = UserFactory.create
      section = ForumSectionFactory.create &.slug("site")
      topic = ForumTopicFactory.create &.section_id(section.id)
      client = AuthHelper.client_for(user)

      unread = JSON.parse(client.get("/api/v1/forum/sections").body)["items"].as_a.first
      unread["unread_topics_count"].as_i.should eq 1

      SaveForumTopicRead.create!(user_id: user.id, topic_id: topic.id, read_count: 1)

      read = JSON.parse(client.get("/api/v1/forum/sections").body)["items"].as_a.first
      read["unread_topics_count"].as_i.should eq 0
    end
  end

  describe "GET /api/v1/forum/sections/:section_slug" do
    it "adds unread counts and the last replier to topics" do
      author = UserFactory.create
      replier = UserFactory.create
      reader = UserFactory.create
      section = ForumSectionFactory.create &.slug("site")
      topic = CreateForumTopic.run!(
        section: section,
        user: author,
        project: nil,
        title: "Тема",
        body: "Первый пост",
      )
      CreateForumPost.run!(topic: topic, user: replier, body: "Ответ", quoted_post_id: nil, quote_text: nil)

      body = JSON.parse(AuthHelper.client_for(reader).get("/api/v1/forum/sections/site").body)
      item = body["items"].as_a.first

      item["last_post_author"]["username"].as_s.should eq replier.username
      item["unread_count"].as_i.should eq 2
      item["read_posts_count"].as_i.should eq 0
      item["first_unread_page"].as_i.should eq 1
    end

    it "points to the page with the first unread post" do
      user = UserFactory.create
      section = ForumSectionFactory.create &.slug("site")
      topic = ForumTopicFactory.create &.section_id(section.id).replies_count(24)
      SaveForumTopicRead.create!(user_id: user.id, topic_id: topic.id, read_count: 20)

      item = JSON.parse(AuthHelper.client_for(user).get("/api/v1/forum/sections/site").body)["items"].as_a.first

      item["unread_count"].as_i.should eq 5
      item["first_unread_page"].as_i.should eq 2
    end

    it "shows the last replier to visitors too" do
      author = UserFactory.create
      replier = UserFactory.create
      section = ForumSectionFactory.create &.slug("site")
      topic = CreateForumTopic.run!(
        section: section,
        user: author,
        project: nil,
        title: "Тема",
        body: "Первый пост",
      )
      CreateForumPost.run!(topic: topic, user: replier, body: "Ответ", quoted_post_id: nil, quote_text: nil)

      item = JSON.parse(ApiClient.new.get("/api/v1/forum/sections/site").body)["items"].as_a.first

      item["last_post_author"]["username"].as_s.should eq replier.username
      item["unread_count"].as_i.should eq 0
      item["read_posts_count"].as_nil.should be_nil
    end
  end

  describe "POST /api/v1/forum/topics/:id/read" do
    it "marks posts up to the given message as read and never goes back" do
      author = UserFactory.create
      reader = UserFactory.create
      replier = UserFactory.create
      section = ForumSectionFactory.create &.slug("site")
      topic = CreateForumTopic.run!(
        section: section,
        user: author,
        project: nil,
        title: "Тема",
        body: "Первый пост",
      )
      first = ForumPostQuery.new.for_topic(topic.id).chronological.first?.not_nil!
      reply = CreateForumPost.run!(topic: topic, user: replier, body: "Ответ", quoted_post_id: nil, quote_text: nil)
      client = AuthHelper.client_for(reader)

      response = client.post("/api/v1/forum/topics/#{topic.id}/read", forum_topic_read: {
        last_post_id: reply.id.to_s,
      })

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["read_posts_count"].as_i.should eq 2
      body["unread_count"].as_i.should eq 0

      earlier = client.post("/api/v1/forum/topics/#{topic.id}/read", forum_topic_read: {
        last_post_id: first.id.to_s,
      })

      JSON.parse(earlier.body)["read_posts_count"].as_i.should eq 2
    end

    it "rejects a post from another topic" do
      reader = UserFactory.create
      section = ForumSectionFactory.create &.slug("site")
      topic = CreateForumTopic.run!(
        section: section,
        user: UserFactory.create,
        project: nil,
        title: "Тема",
        body: "Первый пост",
      )
      other_topic = CreateForumTopic.run!(
        section: section,
        user: UserFactory.create,
        project: nil,
        title: "Другая тема",
        body: "Другой пост",
      )
      foreign = ForumPostQuery.new.for_topic(other_topic.id).chronological.first?.not_nil!

      response = AuthHelper.client_for(reader).post("/api/v1/forum/topics/#{topic.id}/read", forum_topic_read: {
        last_post_id: foreign.id.to_s,
      })

      response.status_code.should eq 422
    end

    it "requires authentication" do
      topic = ForumTopicFactory.create

      response = ApiClient.new.post("/api/v1/forum/topics/#{topic.id}/read", forum_topic_read: {
        last_post_id: "1",
      })

      response.status_code.should eq 401
    end
  end

  describe "last replier bookkeeping" do
    it "falls back to the previous post after the last reply is deleted" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create
      replier = UserFactory.create
      section = ForumSectionFactory.create &.slug("site")
      topic = CreateForumTopic.run!(
        section: section,
        user: author,
        project: nil,
        title: "Тема",
        body: "Первый пост",
      )
      reply = CreateForumPost.run!(topic: topic, user: replier, body: "Ответ", quoted_post_id: nil, quote_text: nil)

      AuthHelper.client_for(admin).delete("/api/v1/forum/posts/#{reply.id}").status_code.should eq 204

      reloaded = ForumTopicQuery.new.id(topic.id).first?.not_nil!
      reloaded.last_post_user_id.should eq author.id
    end
  end
end
