require "../../../spec_helper"
require "xml"

describe "Feeds" do
  describe "GET /api/v1/feeds/projects.rss" do
    it "lists published projects and escapes their titles" do
      project = ProjectFactory.create &.status("published").published_at(Time.utc).title("Rock & Roll <Game>")
      draft = ProjectFactory.create
      adult = ProjectFactory.create &.status("published").published_at(Time.utc).nsfw(true)

      response = ApiClient.new.get("/api/v1/feeds/projects.rss")

      response.status_code.should eq 200
      response.headers["Content-Type"].not_nil!.should start_with "application/rss+xml"
      response.headers["Cache-Control"].should eq "public, max-age=300"
      response.headers["ETag"].should_not be_nil
      XML.parse(response.body)

      response.body.should contain "Rock &amp; Roll &lt;Game&gt;"
      response.body.should contain "/p/#{project.slug}"
      response.body.should_not contain draft.slug
      response.body.should_not contain adult.slug
    end

    it "answers a matching If-None-Match with 304" do
      ProjectFactory.create &.status("published").published_at(Time.utc)

      first = ApiClient.new.get("/api/v1/feeds/projects.rss")
      etag = first.headers["ETag"].not_nil!

      second = ApiClient.new.headers("If-None-Match": etag).get("/api/v1/feeds/projects.rss")

      second.status_code.should eq 304
      second.body.should eq ""

      ProjectFactory.create &.status("published").published_at(Time.utc + 1.minute)

      third = ApiClient.new.headers("If-None-Match": etag).get("/api/v1/feeds/projects.rss")

      third.status_code.should eq 200
      third.headers["ETag"].not_nil!.should_not eq etag
    end
  end

  describe "GET /api/v1/feeds/users/:username.rss" do
    it "lists only the author's visible projects" do
      author = UserFactory.create
      other = UserFactory.create
      mine = ProjectFactory.create &.user_id(author.id).status("published").published_at(Time.utc)
      hidden = ProjectFactory.create &.user_id(author.id).status("published").published_at(Time.utc).nsfw(true)
      theirs = ProjectFactory.create &.user_id(other.id).status("published").published_at(Time.utc)

      response = ApiClient.new.get("/api/v1/feeds/users/#{author.username}.rss")

      response.status_code.should eq 200
      response.body.should contain "/p/#{mine.slug}"
      response.body.should_not contain "/p/#{hidden.slug}"
      response.body.should_not contain "/p/#{theirs.slug}"
    end

    it "returns 404 for an unknown author" do
      ApiClient.new.get("/api/v1/feeds/users/nobody.rss").status_code.should eq 404
    end
  end

  describe "GET /api/v1/feeds/forum/:section.rss" do
    it "lists new topics by creation date with a first-post preview" do
      section = ForumSectionFactory.create &.slug("site")
      older = ForumTopicFactory.create &.section_id(section.id).title("Старая тема").created_at(2.hours.ago)
      newer = ForumTopicFactory.create &.section_id(section.id).title("Новая тема").created_at(1.hour.ago)
      ForumPostFactory.create &.topic_id(older.id).body("**Первый** текст темы")
      ForumPostFactory.create &.topic_id(older.id).body("Ответ, который не должен попасть в выжимку")

      response = ApiClient.new.get("/api/v1/feeds/forum/site.rss")

      response.status_code.should eq 200
      response.body.index("Новая тема").not_nil!.should be < response.body.index("Старая тема").not_nil!
      response.body.should contain "Первый текст темы"
      response.body.should_not contain "Ответ, который не должен попасть в выжимку"
      response.body.should contain "/forum/site/#{older.slug}"
      response.body.should contain "/forum/site/#{newer.slug}"
    end

    it "hides topics of drafts and adult projects in the projects section" do
      section = ForumSectionFactory.create &.slug("projects")
      visible = ProjectFactory.create &.status("published").published_at(Time.utc)
      draft = ProjectFactory.create
      adult = ProjectFactory.create &.status("published").published_at(Time.utc).nsfw(true)

      visible_topic = ForumTopicFactory.create &.section_id(section.id).project_id(visible.id).title("Видимая тема")
      ForumTopicFactory.create &.section_id(section.id).project_id(draft.id).title("Черновая тема")
      ForumTopicFactory.create &.section_id(section.id).project_id(adult.id).title("Тема 18+")

      response = ApiClient.new.get("/api/v1/feeds/forum/projects.rss")

      response.status_code.should eq 200
      response.body.should contain visible_topic.title
      response.body.should_not contain "Черновая тема"
      response.body.should_not contain "Тема 18+"
    end

    it "returns 404 for an unknown section" do
      ApiClient.new.get("/api/v1/feeds/forum/nope.rss").status_code.should eq 404
    end
  end

  describe "GET /api/v1/feeds/forum/:section/:topic.rss" do
    it "lists messages newest first with links to their pages" do
      section = ForumSectionFactory.create &.slug("site")
      topic = ForumTopicFactory.create &.section_id(section.id).title("Большая тема")
      first = ForumPostFactory.create &.topic_id(topic.id).body("Первый **абзац**")
      second = ForumPostFactory.create &.topic_id(topic.id).body("Второй ответ")

      response = ApiClient.new.get("/api/v1/feeds/forum/site/#{topic.slug}.rss")

      response.status_code.should eq 200
      XML.parse(response.body)
      response.body.index("Второй ответ").not_nil!.should be < response.body.index("Первый абзац").not_nil!
      response.body.should contain "Re: #{topic.title}"
      response.body.should contain "#post-#{first.id}"
      response.body.should contain "#post-#{second.id}"
    end

    it "links messages from the second page with a page query" do
      section = ForumSectionFactory.create &.slug("site")
      topic = ForumTopicFactory.create &.section_id(section.id)
      posts = (1..21).map do |number|
        ForumPostFactory.create &.topic_id(topic.id).body("Сообщение #{number}")
      end

      response = ApiClient.new.get("/api/v1/feeds/forum/site/#{topic.slug}.rss")

      response.status_code.should eq 200
      response.body.should contain "?page=2#post-#{posts.last.id}"
      response.body.should contain "#post-#{posts.first.id}"
      response.body.should_not contain "?page=1#post-"
    end

    it "returns 404 for a topic of a draft project" do
      section = ForumSectionFactory.create &.slug("projects")
      project = ProjectFactory.create
      topic = ForumTopicFactory.create &.section_id(section.id).project_id(project.id)
      ForumPostFactory.create &.topic_id(topic.id)

      ApiClient.new.get("/api/v1/feeds/forum/projects/#{topic.slug}.rss").status_code.should eq 404
    end

    it "returns 404 for an unknown topic" do
      ForumSectionFactory.create &.slug("site")

      ApiClient.new.get("/api/v1/feeds/forum/site/nope.rss").status_code.should eq 404
    end
  end

  describe "GET /api/v1/feeds/projects/:slug/devlogs.rss" do
    it "lists devlog entries newest first" do
      project = ProjectFactory.create &.status("published").published_at(Time.utc)
      older = DevlogFactory.create &.project_id(project.id).title("Старая запись").created_at(2.hours.ago)
      newer = DevlogFactory.create &.project_id(project.id).title("Новая запись").created_at(1.hour.ago)

      response = ApiClient.new.get("/api/v1/feeds/projects/#{project.slug}/devlogs.rss")

      response.status_code.should eq 200
      response.body.index("Новая запись").not_nil!.should be < response.body.index("Старая запись").not_nil!
      response.body.should contain "/p/#{project.slug}/devlog/#{newer.slug}"
      response.body.should contain "/p/#{project.slug}/devlog/#{older.slug}"
    end

    it "returns 404 for a draft or adult project" do
      draft = ProjectFactory.create
      DevlogFactory.create &.project_id(draft.id)

      ApiClient.new.get("/api/v1/feeds/projects/#{draft.slug}/devlogs.rss").status_code.should eq 404

      adult = ProjectFactory.create &.status("published").published_at(Time.utc).nsfw(true)
      DevlogFactory.create &.project_id(adult.id)

      ApiClient.new.get("/api/v1/feeds/projects/#{adult.slug}/devlogs.rss").status_code.should eq 404
    end

    it "returns 404 for an unknown project" do
      ApiClient.new.get("/api/v1/feeds/projects/nope/devlogs.rss").status_code.should eq 404
    end
  end
end
