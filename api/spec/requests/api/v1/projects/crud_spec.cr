require "../../../../spec_helper"

describe Api::V1::Projects do
  describe "POST /api/v1/projects" do
    it "creates a draft owned by the current user" do
      user = UserFactory.create

      response = AuthHelper.client_for(user).post("/api/v1/projects", project: {
        title:   "My First Game",
        tagline: "A small experiment",
        kind:    "game",
      })

      response.status_code.should eq 201

      project = ProjectQuery.new.slug("my-first-game").first?
      project.should_not be_nil
      project.not_nil!.user_id.should eq user.id
      project.not_nil!.status.should eq "draft"
    end

    it "requires authentication" do
      response = ApiClient.new.post("/api/v1/projects", project: {
        title: "Anonymous Game",
        kind:  "game",
      })

      response.status_code.should eq 401
    end

    it "assigns tags by slug" do
      user = UserFactory.create
      Tag::SaveOperation.create!(name: "RPG", slug: "rpg")

      response = AuthHelper.client_for(user).post("/api/v1/projects", {
        project:   {title: "Tagged Game", kind: "game"},
        tag_slugs: ["rpg"],
      })

      response.status_code.should eq 201
      body = JSON.parse(response.body)
      body["tags"].as_a.map(&.["slug"].as_s).should eq ["rpg"]
    end
  end

  describe "publishing" do
    it "publishes only the owner's project" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)

      response = AuthHelper.client_for(owner).post("/api/v1/projects/#{project.slug}/publish")

      response.status_code.should eq 200
      ProjectQuery.new.id(project.id).first?.not_nil!.status.should eq "published"
      ProjectQuery.new.id(project.id).first?.not_nil!.published_at.should_not be_nil
    end

    it "returns 404 for another user's project" do
      project = ProjectFactory.create
      stranger = UserFactory.create

      response = AuthHelper.client_for(stranger).post("/api/v1/projects/#{project.slug}/publish")

      response.status_code.should eq 404
    end
  end

  describe "GET /api/v1/projects" do
    it "lists only published projects" do
      published = ProjectFactory.create &.status("published").published_at(Time.utc)
      ProjectFactory.create

      response = ApiClient.exec(Api::V1::Projects::Index)

      response.status_code.should eq 200
      items = JSON.parse(response.body)["items"].as_a
      items.size.should eq 1
      items.first["slug"].as_s.should eq published.slug
    end
  end

  describe "GET /api/v1/projects/:slug" do
    it "hides drafts from visitors" do
      project = ProjectFactory.create

      response = ApiClient.new.get("/api/v1/projects/#{project.slug}")

      response.status_code.should eq 404
    end

    it "shows a published project" do
      project = ProjectFactory.create &.status("published").published_at(Time.utc)

      response = ApiClient.new.get("/api/v1/projects/#{project.slug}")

      response.status_code.should eq 200
      JSON.parse(response.body)["slug"].as_s.should eq project.slug
    end
  end
end
