require "../../../../spec_helper"

describe "Forum blacklist" do
  it "hides topics of blocked accounts but keeps the section counters" do
    alice = UserFactory.create
    bob = UserFactory.create
    carol = UserFactory.create
    section = ForumSectionFactory.create &.slug("site")
    UserBlockFactory.create &.blocker_id(alice.id).blocked_user_id(bob.id)

    bob_topic = CreateForumTopic.run!(section: section, user: bob, project: nil, title: "Тема Боба", body: "Скрытый текст")
    carol_topic = CreateForumTopic.run!(section: section, user: carol, project: nil, title: "Тема Кэрол", body: "Открытый текст")

    body = JSON.parse(AuthHelper.client_for(alice).get("/api/v1/forum/sections/site").body)
    body["items"].as_a.map(&.["title"].as_s).should eq [carol_topic.title]
    body["meta"]["total"].as_i.should eq 1
    # The public counters still describe the whole section.
    body["section"]["topics_count"].as_i.should eq 2

    AuthHelper.client_for(alice)
      .get("/api/v1/forum/sections/site/topics/#{bob_topic.slug}")
      .status_code.should eq 404

    guest = JSON.parse(ApiClient.new.get("/api/v1/forum/sections/site").body)
    guest["items"].as_a.size.should eq 2
  end

  it "hides messages of blocked accounts and keeps them out of unread counters" do
    alice = UserFactory.create
    bob = UserFactory.create
    carol = UserFactory.create
    section = ForumSectionFactory.create &.slug("site")
    UserBlockFactory.create &.blocker_id(alice.id).blocked_user_id(bob.id)
    client = AuthHelper.client_for(alice)

    topic = CreateForumTopic.run!(section: section, user: carol, project: nil, title: "Тема", body: "Первый пост")
    first_post = ForumPostQuery.new.for_topic(topic.id).chronological.first?.not_nil!
    CreateForumPost.run!(topic: topic, user: bob, body: "Скрытый ответ", quoted_post_id: nil, quote_text: nil)

    item = JSON.parse(client.get("/api/v1/forum/sections/site").body)["items"].as_a.first
    item["replies_count"].as_i.should eq 1
    item["unread_count"].as_i.should eq 1
    item["first_unread_post_id"].as_i64.should eq first_post.id
    item["last_post_author"].as_nil.should be_nil

    section_body = JSON.parse(client.get("/api/v1/forum/sections/site").body)
    section_body["section"]["unread_topics_count"].as_i.should eq 1

    page = JSON.parse(client.get("/api/v1/forum/sections/site/topics/#{topic.slug}").body)
    page["items"].as_a.size.should eq 1
    page["items"].as_a.first["author"]["username"].as_s.should eq carol.username
    page["meta"]["total"].as_i.should eq 1
    page["topic"]["replies_count"].as_i.should eq 1
    page["topic"]["first_unread_post_id"].as_i64.should eq first_post.id

    response = client.post("/api/v1/forum/topics/#{topic.id}/read", forum_topic_read: {
      last_post_id: first_post.id.to_s,
    })
    JSON.parse(response.body)["unread_count"].as_i.should eq 0

    # A blocked reply must not light the badge back up.
    CreateForumPost.run!(topic: topic, user: bob, body: "Ещё один скрытый ответ", quoted_post_id: nil, quote_text: nil)

    item = JSON.parse(client.get("/api/v1/forum/sections/site").body)["items"].as_a.first
    item["unread_count"].as_i.should eq 0
    JSON.parse(client.get("/api/v1/forum/sections/site").body)["section"]["unread_topics_count"].as_i.should eq 0

    # A visible reply is counted normally again.
    reply = CreateForumPost.run!(topic: topic, user: carol, body: "Открытый ответ", quoted_post_id: nil, quote_text: nil)
    item = JSON.parse(client.get("/api/v1/forum/sections/site").body)["items"].as_a.first
    item["unread_count"].as_i.should eq 1
    item["first_unread_post_id"].as_i64.should eq reply.id

    page = JSON.parse(client.get("/api/v1/forum/sections/site/topics/#{topic.slug}").body)
    page["items"].as_a.map(&.["author"]["username"].as_s).should eq [carol.username, carol.username]
    page["meta"]["total"].as_i.should eq 2
    page["topic"]["unread_count"].as_i.should eq 1
    page["topic"]["first_unread_post_id"].as_i64.should eq reply.id
  end

  it "pages only the visible messages" do
    alice = UserFactory.create
    bob = UserFactory.create
    carol = UserFactory.create
    section = ForumSectionFactory.create &.slug("site")
    UserBlockFactory.create &.blocker_id(alice.id).blocked_user_id(bob.id)
    client = AuthHelper.client_for(alice)

    topic = CreateForumTopic.run!(section: section, user: carol, project: nil, title: "Длинная тема", body: "Первый пост")
    2.times { |index| CreateForumPost.run!(topic: topic, user: carol, body: "Открытый #{index}", quoted_post_id: nil, quote_text: nil) }
    20.times { |index| CreateForumPost.run!(topic: topic, user: bob, body: "Скрытый #{index}", quoted_post_id: nil, quote_text: nil) }

    body = JSON.parse(client.get("/api/v1/forum/sections/site/topics/#{topic.slug}?per_page=1").body)
    body["meta"]["total"].as_i.should eq 3
    body["meta"]["pages"].as_i.should eq 3
    body["items"].as_a.size.should eq 1

    second = JSON.parse(client.get("/api/v1/forum/sections/site/topics/#{topic.slug}?per_page=1&page=2").body)
    second["items"].as_a.size.should eq 1
    second["items"].as_a.first["author"]["username"].as_s.should eq carol.username
  end

  it "hides quotes of blocked authors from the blocker only" do
    alice = UserFactory.create
    bob = UserFactory.create
    carol = UserFactory.create
    section = ForumSectionFactory.create &.slug("site")
    UserBlockFactory.create &.blocker_id(alice.id).blocked_user_id(bob.id)

    topic = CreateForumTopic.run!(section: section, user: carol, project: nil, title: "С цитатой", body: "Первый пост")
    quoted = ForumPostFactory.create do |factory|
      factory.topic_id(topic.id)
      factory.user_id(bob.id)
    end
    ForumPostFactory.create do |factory|
      factory.topic_id(topic.id)
      factory.user_id(carol.id)
      factory.quoted_post_id(quoted.id)
      factory.quote_author_username(bob.username)
      factory.quote_author_name(bob.name)
      factory.quote_body("Скрытые слова")
    end

    path = "/api/v1/forum/sections/site/topics/#{topic.slug}"
    blocker_view = JSON.parse(AuthHelper.client_for(alice).get(path).body)
    blocker_view["items"].as_a.last["quote"].as_nil.should be_nil

    guest_view = JSON.parse(ApiClient.new.get(path).body)
    guest_view["items"].as_a.last["quote"]["author_username"].as_s.should eq bob.username
  end

  it "returns 404 for a direct request to a hidden message" do
    alice = UserFactory.create
    bob = UserFactory.create
    carol = UserFactory.create
    section = ForumSectionFactory.create &.slug("site")
    UserBlockFactory.create &.blocker_id(alice.id).blocked_user_id(bob.id)

    topic = CreateForumTopic.run!(section: section, user: carol, project: nil, title: "Тема", body: "Первый пост")
    hidden = CreateForumPost.run!(topic: topic, user: bob, body: "Скрыто", quoted_post_id: nil, quote_text: nil)

    AuthHelper.client_for(alice)
      .get("/api/v1/forum/posts/#{hidden.id}/reactions")
      .status_code.should eq 404
  end

  it "hides project forum topics without hiding the project" do
    alice = UserFactory.create
    bob = UserFactory.create
    carol = UserFactory.create
    project = ProjectFactory.create &.user_id(carol.id).status("published").published_at(Time.utc)
    projects = ForumSectionFactory.create &.slug("projects")
    UserBlockFactory.create &.blocker_id(alice.id).blocked_user_id(bob.id)
    CreateForumTopic.run!(section: projects, user: bob, project: project, title: "Тема Боба", body: "Скрытый текст")

    client = AuthHelper.client_for(alice)
    client.get("/api/v1/projects/#{project.slug}").status_code.should eq 200

    body = JSON.parse(client.get("/api/v1/projects/#{project.slug}/forum/topics").body)
    body["items"].as_a.should be_empty
    body["meta"]["total"].as_i.should eq 0

    guest = JSON.parse(ApiClient.new.get("/api/v1/projects/#{project.slug}/forum/topics").body)
    guest["items"].as_a.size.should eq 1
  end
end
