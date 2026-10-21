require "../../../../spec_helper"

describe Api::V1::Projects::Forum do
  describe "GET /api/v1/projects/:slug/forum/topics" do
    it "shows project topics to visitors when the project is published" do
      project = ProjectFactory.create &.status("published").published_at(Time.utc)
      section = ForumSectionFactory.create &.slug("projects")
      ForumTopicFactory.create &.section_id(section.id).project_id(project.id)

      response = ApiClient.new.get("/api/v1/projects/#{project.slug}/forum/topics")

      response.status_code.should eq 200
      JSON.parse(response.body)["items"].as_a.size.should eq 1
    end

    it "hides a draft project's forum from visitors" do
      project = ProjectFactory.create
      section = ForumSectionFactory.create &.slug("projects")
      ForumTopicFactory.create &.section_id(section.id).project_id(project.id)

      response = ApiClient.new.get("/api/v1/projects/#{project.slug}/forum/topics")

      response.status_code.should eq 404
    end

    it "does not list draft project topics in the public projects section" do
      project = ProjectFactory.create
      section = ForumSectionFactory.create &.slug("projects")
      topic = ForumTopicFactory.create &.section_id(section.id).project_id(project.id)

      response = ApiClient.new.get("/api/v1/forum/sections/projects")

      response.status_code.should eq 200
      JSON.parse(response.body)["items"].as_a.should be_empty

      direct = ApiClient.new.get("/api/v1/forum/sections/projects/topics/#{topic.slug}")
      direct.status_code.should eq 404
    end

    it "lets the owner see a draft project's forum and topic" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)
      section = ForumSectionFactory.create &.slug("projects")
      topic = ForumTopicFactory.create &.section_id(section.id).project_id(project.id).user_id(owner.id)
      client = AuthHelper.client_for(owner)

      client.get("/api/v1/projects/#{project.slug}/forum/topics").status_code.should eq 200
      client.get("/api/v1/forum/sections/projects/topics/#{topic.slug}").status_code.should eq 200
    end
  end

  describe "POST /api/v1/projects/:slug/forum/topics" do
    it "creates a project topic for a signed-in user" do
      project = ProjectFactory.create &.status("published").published_at(Time.utc)
      section = ForumSectionFactory.create &.slug("projects")
      user = UserFactory.create

      response = AuthHelper.client_for(user).post("/api/v1/projects/#{project.slug}/forum/topics", forum_topic: {
        title: "Вопрос по проекту",
        body:  "Как запустить сборку?",
      })

      response.status_code.should eq 201
      topic = ForumTopicQuery.new.for_project(project.id).first?
      topic.should_not be_nil
      topic.not_nil!.section_id.should eq section.id
      topic.not_nil!.project_id.should eq project.id

      json = JSON.parse(response.body)
      json["section"]["slug"].as_s.should eq "projects"
      json["project"]["slug"].as_s.should eq project.slug
    end

    it "returns 404 for a draft project the user does not own" do
      project = ProjectFactory.create
      ForumSectionFactory.create &.slug("projects")

      response = AuthHelper.client_for(UserFactory.create).post("/api/v1/projects/#{project.slug}/forum/topics", forum_topic: {
        title: "Чужой черновик",
        body:  "Не должно создаться",
      })

      response.status_code.should eq 404
      ForumTopicQuery.new.for_project(project.id).select_count.should eq 0
    end
  end

  describe "user and project deletion" do
    it "removes a user's topics and posts and recalculates other topics" do
      author = UserFactory.create
      other = UserFactory.create
      section = ForumSectionFactory.create

      own_topic = ForumTopicFactory.create &.section_id(section.id).user_id(author.id)
      other_topic = ForumTopicFactory.create &.section_id(section.id).user_id(other.id)
      first_post = ForumPostFactory.create &.topic_id(other_topic.id).user_id(other.id)
      reply = ForumPostFactory.create &.topic_id(other_topic.id).user_id(author.id)
      ForumPostFactory.create &.topic_id(other_topic.id).user_id(other.id)
      ForumTopic::SaveOperation.update!(other_topic, replies_count: 2, last_post_at: reply.created_at)

      DeleteUserContent.run!(user: author)
      User::DeleteOperation.delete!(author)

      ForumTopicQuery.new.id(own_topic.id).first?.should be_nil
      ForumPostQuery.new.id(reply.id).first?.should be_nil
      ForumPostQuery.new.for_topic(other_topic.id).select_count.should eq 2
      ForumTopicQuery.new.id(other_topic.id).first?.not_nil!.replies_count.should eq 1
    end

    it "deletes a project's forum topics with the project" do
      project = ProjectFactory.create
      section = ForumSectionFactory.create &.slug("projects")
      topic = ForumTopicFactory.create &.section_id(section.id).project_id(project.id)
      ForumPostFactory.create &.topic_id(topic.id)

      Project::DeleteOperation.delete!(project)

      ForumTopicQuery.new.id(topic.id).first?.should be_nil
      ForumPostQuery.new.for_topic(topic.id).select_count.should eq 0
    end
  end
end
