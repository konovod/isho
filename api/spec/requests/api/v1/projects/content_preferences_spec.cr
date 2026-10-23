require "../../../../spec_helper"

describe "Project content options" do
  describe "POST /api/v1/projects" do
    it "saves the NSFW flag and AI usage level" do
      user = UserFactory.create

      response = AuthHelper.client_for(user).post("/api/v1/projects", project: {
        title:    "Adult AI Game",
        nsfw:     true,
        ai_usage: "significant",
      })

      response.status_code.should eq 201
      body = JSON.parse(response.body)
      body["nsfw"].as_bool.should be_true
      body["ai_usage"].as_s.should eq "significant"

      project = ProjectQuery.new.slug("adult-ai-game").first?
      project.should_not be_nil
      project.not_nil!.nsfw.should be_true
      project.not_nil!.ai_usage.should eq "significant"
    end

    it "defaults to a non-NSFW AI-free project" do
      user = UserFactory.create

      response = AuthHelper.client_for(user).post("/api/v1/projects", project: {
        title: "Plain Game",
      })

      response.status_code.should eq 201
      body = JSON.parse(response.body)
      body["nsfw"].as_bool.should be_false
      body["ai_usage"].as_s.should eq "ai_free"
    end

    it "rejects an unknown AI usage level" do
      user = UserFactory.create

      response = AuthHelper.client_for(user).post("/api/v1/projects", project: {
        title:    "Weird Game",
        ai_usage: "assisted",
      })

      response.status_code.should eq 422
      details = JSON.parse(response.body)["error"]["details"]
      details["ai_usage"].as_a.should_not be_empty
    end
  end

  describe "GET /api/v1/projects" do
    it "hides adult projects from visitors" do
      visible = ProjectFactory.create &.status("published").published_at(Time.utc)
      ProjectFactory.create &.status("published").published_at(Time.utc).nsfw(true)

      response = ApiClient.new.get("/api/v1/projects")

      response.status_code.should eq 200
      items = JSON.parse(response.body)["items"].as_a
      items.map(&.["slug"].as_s).should eq [visible.slug]
    end

    it "shows adult projects to signed-in users by default" do
      adult = ProjectFactory.create &.status("published").published_at(Time.utc).nsfw(true)
      user = UserFactory.create

      response = AuthHelper.client_for(user).get("/api/v1/projects")

      response.status_code.should eq 200
      JSON.parse(response.body)["items"].as_a.map(&.["slug"].as_s).should contain adult.slug
    end

    it "hides adult projects from a user who turned them off" do
      ProjectFactory.create &.status("published").published_at(Time.utc).nsfw(true)
      user = UserFactory.create &.show_nsfw(false)

      response = AuthHelper.client_for(user).get("/api/v1/projects")

      response.status_code.should eq 200
      JSON.parse(response.body)["items"].as_a.should be_empty
    end

    it "hides projects above the user's AI usage limit" do
      ai_free = ProjectFactory.create &.status("published").published_at(Time.utc)
      partial = ProjectFactory.create &.status("published").published_at(Time.utc).ai_usage("partial")
      ProjectFactory.create &.status("published").published_at(Time.utc).ai_usage("significant")
      ProjectFactory.create &.status("published").published_at(Time.utc).ai_usage("full")

      user = UserFactory.create &.max_ai_usage("partial")
      response = AuthHelper.client_for(user).get("/api/v1/projects")

      response.status_code.should eq 200
      slugs = JSON.parse(response.body)["items"].as_a.map(&.["slug"].as_s)
      slugs.should contain ai_free.slug
      slugs.should contain partial.slug
      slugs.size.should eq 2
    end

    it "keeps the catalogue complete for moderators" do
      ProjectFactory.create &.status("published").published_at(Time.utc).nsfw(true)
      admin = UserFactory.create &.is_admin(true).show_nsfw(false)

      response = AuthHelper.client_for(admin).get("/api/v1/projects")

      response.status_code.should eq 200
      JSON.parse(response.body)["items"].as_a.size.should eq 1
    end
  end

  describe "GET /api/v1/projects/:slug" do
    it "returns 404 for an adult project to visitors" do
      project = ProjectFactory.create &.status("published").published_at(Time.utc).nsfw(true)

      ApiClient.new.get("/api/v1/projects/#{project.slug}").status_code.should eq 404
    end

    it "returns 404 when the viewer hid adult projects" do
      project = ProjectFactory.create &.status("published").published_at(Time.utc).nsfw(true)
      user = UserFactory.create &.show_nsfw(false)

      AuthHelper.client_for(user).get("/api/v1/projects/#{project.slug}").status_code.should eq 404
    end

    it "returns 404 when the project is above the AI usage limit" do
      project = ProjectFactory.create &.status("published").published_at(Time.utc).ai_usage("full")
      user = UserFactory.create &.max_ai_usage("partial")

      AuthHelper.client_for(user).get("/api/v1/projects/#{project.slug}").status_code.should eq 404
    end

    it "lets the owner open a project hidden by their own preferences" do
      owner = UserFactory.create &.show_nsfw(false)
      project = ProjectFactory.create &.user_id(owner.id).status("published").published_at(Time.utc).nsfw(true)

      AuthHelper.client_for(owner).get("/api/v1/projects/#{project.slug}").status_code.should eq 200
    end
  end

  describe "forum visibility" do
    it "hides topics of adult projects from visitors" do
      project = ProjectFactory.create &.status("published").published_at(Time.utc).nsfw(true)
      section = ForumSectionFactory.create &.slug("projects")
      topic = ForumTopicFactory.create &.section_id(section.id).project_id(project.id)

      listing = ApiClient.new.get("/api/v1/forum/sections/projects")
      listing.status_code.should eq 200
      JSON.parse(listing.body)["items"].as_a.should be_empty

      ApiClient.new.get("/api/v1/forum/sections/projects/topics/#{topic.slug}").status_code.should eq 404

      sections = ApiClient.new.get("/api/v1/forum/sections")
      projects_section = JSON.parse(sections.body)["items"].as_a.find { |item| item["slug"] == "projects" }
      projects_section.not_nil!["topics_count"].as_i.should eq 0
    end

    it "shows topics of adult projects to signed-in users by default" do
      project = ProjectFactory.create &.status("published").published_at(Time.utc).nsfw(true)
      section = ForumSectionFactory.create &.slug("projects")
      topic = ForumTopicFactory.create &.section_id(section.id).project_id(project.id)
      user = UserFactory.create

      client = AuthHelper.client_for(user)
      listing = client.get("/api/v1/forum/sections/projects")
      listing.status_code.should eq 200
      JSON.parse(listing.body)["items"].as_a.size.should eq 1
      client.get("/api/v1/forum/sections/projects/topics/#{topic.slug}").status_code.should eq 200
    end
  end

  describe "GET /api/v1/users/:username" do
    it "filters the profile catalogue with the viewer's preferences" do
      author = UserFactory.create
      visible = ProjectFactory.create &.user_id(author.id).status("published").published_at(Time.utc)
      ProjectFactory.create &.user_id(author.id).status("published").published_at(Time.utc).nsfw(true)

      response = ApiClient.new.get("/api/v1/users/#{author.username}")

      response.status_code.should eq 200
      JSON.parse(response.body)["projects"].as_a.map(&.["slug"].as_s).should eq [visible.slug]
    end
  end
end
