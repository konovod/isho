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
      project.not_nil!.dev_status.should eq "active"
      project.not_nil!.genre.should be_nil
    end

    it "stores the development status and genre of a game" do
      user = UserFactory.create

      response = AuthHelper.client_for(user).post("/api/v1/projects", project: {
        title:      "Beta Horror",
        kind:       "game",
        dev_status: "beta",
        genre:      "horror",
      })

      response.status_code.should eq 201
      body = JSON.parse(response.body)
      body["dev_status"].as_s.should eq "beta"
      body["genre"].as_s.should eq "horror"

      project = ProjectQuery.new.slug("beta-horror").first?.not_nil!
      project.dev_status.should eq "beta"
      project.genre.should eq "horror"
    end

    it "drops the genre when the project is not a game" do
      user = UserFactory.create

      AuthHelper.client_for(user).post("/api/v1/projects", project: {
        title: "Genre Tool",
        kind:  "tool",
        genre: "horror",
      }).status_code.should eq 201

      ProjectQuery.new.slug("genre-tool").first?.not_nil!.genre.should be_nil
    end

    it "rejects an unknown genre" do
      user = UserFactory.create

      response = AuthHelper.client_for(user).post("/api/v1/projects", project: {
        title: "Strange Game",
        kind:  "game",
        genre: "shopping",
      })

      response.status_code.should eq 422
      ProjectQuery.new.slug("strange-game").first?.should be_nil
    end

    it "rejects an unknown development status" do
      user = UserFactory.create

      response = AuthHelper.client_for(user).post("/api/v1/projects", project: {
        title:      "Strange Status",
        kind:       "game",
        dev_status: "shipped",
      })

      response.status_code.should eq 422
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

  describe "PATCH /api/v1/projects/:slug" do
    it "updates the development status" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)

      response = AuthHelper.client_for(owner).patch("/api/v1/projects/#{project.slug}", project: {
        dev_status: "completed",
      })

      response.status_code.should eq 200
      ProjectQuery.new.id(project.id).first?.not_nil!.dev_status.should eq "completed"
    end

    it "clears the genre when the project stops being a game" do
      owner = UserFactory.create
      project = ProjectFactory.create do |operation|
        operation.user_id(owner.id)
        operation.genre("horror")
      end

      response = AuthHelper.client_for(owner).patch("/api/v1/projects/#{project.slug}", project: {
        kind: "tool",
      })

      response.status_code.should eq 200
      ProjectQuery.new.id(project.id).first?.not_nil!.genre.should be_nil
    end

    it "clears the genre when the form sends an empty value" do
      owner = UserFactory.create
      project = ProjectFactory.create do |operation|
        operation.user_id(owner.id)
        operation.genre("horror")
      end

      response = AuthHelper.client_for(owner).patch("/api/v1/projects/#{project.slug}", project: {
        kind:  "game",
        genre: "",
      })

      response.status_code.should eq 200
      ProjectQuery.new.id(project.id).first?.not_nil!.genre.should be_nil
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

    it "marks a project with a browser build as playable" do
      playable = ProjectFactory.create &.status("published").published_at(Time.utc)
      build = SaveBuild.create!(
        project_id: playable.id,
        public_id: UUID.random.to_s,
        kind: "web",
        entry_path: "index.html",
        size_bytes: 1_i64,
      )
      plain = ProjectFactory.create &.status("published").published_at(Time.utc)

      response = ApiClient.exec(Api::V1::Projects::Index)

      response.status_code.should eq 200
      items = JSON.parse(response.body)["items"].as_a
      items.find { |item| item["slug"].as_s == playable.slug }.not_nil!["play_build_id"].as_i64.should eq build.id
      items.find { |item| item["slug"].as_s == plain.slug }.not_nil!["play_build_id"].as_nil.should be_nil
    end
  end

  describe "GET /api/v1/users/:username" do
    it "marks a card on a profile as playable" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id).status("published").published_at(Time.utc)
      build = SaveBuild.create!(
        project_id: project.id,
        public_id: UUID.random.to_s,
        kind: "web",
        entry_path: "index.html",
        size_bytes: 1_i64,
      )

      response = ApiClient.new.get("/api/v1/users/#{user.username}")

      response.status_code.should eq 200
      JSON.parse(response.body)["projects"].as_a.first["play_build_id"].as_i64.should eq build.id
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
