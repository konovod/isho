require "../../../../spec_helper"

describe Api::V1::Projects::Devlogs do
  describe "POST /api/v1/projects/:slug/devlogs" do
    it "creates a devlog owned by the project" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)

      response = AuthHelper.client_for(owner).post("/api/v1/projects/#{project.slug}/devlogs", devlog: {
        title: "Первая запись",
        body:  "## Заголовок\n\nТекст дневника.",
      })

      response.status_code.should eq 201

      body = JSON.parse(response.body)
      body["slug"].as_s.should eq "pervaya-zapis"
      body["title"].as_s.should eq "Первая запись"

      devlog = DevlogQuery.new.project_id(project.id).first?
      devlog.should_not be_nil
      devlog.not_nil!.body.should eq "## Заголовок\n\nТекст дневника."
    end

    it "makes slugs unique within the project and stable across updates" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)
      client = AuthHelper.client_for(owner)

      first = JSON.parse(client.post("/api/v1/projects/#{project.slug}/devlogs", devlog: {
        title: "Один заголовок",
        body:  "Первый текст",
      }).body)
      second = JSON.parse(client.post("/api/v1/projects/#{project.slug}/devlogs", devlog: {
        title: "Один заголовок",
        body:  "Второй текст",
      }).body)

      first["slug"].as_s.should eq "odin-zagolovok"
      second["slug"].as_s.should eq "odin-zagolovok-2"

      updated = client.patch("/api/v1/projects/#{project.slug}/devlogs/#{second["id"]}", devlog: {
        title: "Новый заголовок",
        body:  "Обновлённый текст",
      })

      updated.status_code.should eq 200
      JSON.parse(updated.body)["slug"].as_s.should eq "odin-zagolovok-2"
    end

    it "rejects blank bodies" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)

      response = AuthHelper.client_for(owner).post("/api/v1/projects/#{project.slug}/devlogs", devlog: {
        title: "Пустая запись",
        body:  "   ",
      })

      response.status_code.should eq 422
      DevlogQuery.new.project_id(project.id).select_count.should eq 0
    end

    it "returns 404 for another user's project" do
      project = ProjectFactory.create
      stranger = UserFactory.create

      response = AuthHelper.client_for(stranger).post("/api/v1/projects/#{project.slug}/devlogs", devlog: {
        title: "Чужая запись",
        body:  "Не должно сохраниться",
      })

      response.status_code.should eq 404
      DevlogQuery.new.project_id(project.id).select_count.should eq 0
    end
  end

  describe "GET /api/v1/projects/:slug/devlogs" do
    it "hides devlogs of a draft project from visitors" do
      project = ProjectFactory.create
      DevlogFactory.create &.project_id(project.id)

      response = ApiClient.new.get("/api/v1/projects/#{project.slug}/devlogs")

      response.status_code.should eq 404
    end

    it "shows devlogs of a published project" do
      project = ProjectFactory.create &.status("published").published_at(Time.utc)
      DevlogFactory.create &.project_id(project.id)

      response = ApiClient.new.get("/api/v1/projects/#{project.slug}/devlogs")

      response.status_code.should eq 200
      JSON.parse(response.body)["items"].as_a.size.should eq 1
    end

    it "lets the owner read devlogs of a draft project" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)
      DevlogFactory.create &.project_id(project.id)

      response = AuthHelper.client_for(owner).get("/api/v1/projects/#{project.slug}/devlogs")

      response.status_code.should eq 200
    end
  end

  describe "GET /api/v1/projects/:slug/devlogs/:devlog_slug" do
    it "returns one devlog" do
      project = ProjectFactory.create &.status("published").published_at(Time.utc)
      devlog = DevlogFactory.create &.project_id(project.id)

      response = ApiClient.new.get("/api/v1/projects/#{project.slug}/devlogs/#{devlog.slug}")

      response.status_code.should eq 200
      JSON.parse(response.body)["id"].as_i64.should eq devlog.id
    end

    it "returns 404 for an unknown slug" do
      project = ProjectFactory.create &.status("published").published_at(Time.utc)

      response = ApiClient.new.get("/api/v1/projects/#{project.slug}/devlogs/missing")

      response.status_code.should eq 404
    end
  end

  describe "PATCH and DELETE /api/v1/projects/:slug/devlogs/:id" do
    it "updates and deletes the owner's devlog" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)
      devlog = DevlogFactory.create &.project_id(project.id)
      client = AuthHelper.client_for(owner)

      updated = client.patch("/api/v1/projects/#{project.slug}/devlogs/#{devlog.id}", devlog: {
        title: "Новое название",
        body:  "Новый текст",
      })

      updated.status_code.should eq 200
      JSON.parse(updated.body)["body"].as_s.should eq "Новый текст"

      client.delete("/api/v1/projects/#{project.slug}/devlogs/#{devlog.id}").status_code.should eq 204
      DevlogQuery.new.id(devlog.id).first?.should be_nil
    end

    it "does not let a stranger touch the devlog" do
      project = ProjectFactory.create
      devlog = DevlogFactory.create &.project_id(project.id)
      stranger = AuthHelper.client_for(UserFactory.create)

      stranger.patch("/api/v1/projects/#{project.slug}/devlogs/#{devlog.id}", devlog: {
        title: "Взлом",
        body:  "Взлом",
      }).status_code.should eq 404

      stranger.delete("/api/v1/projects/#{project.slug}/devlogs/#{devlog.id}").status_code.should eq 404
      DevlogQuery.new.id(devlog.id).first?.should_not be_nil
    end
  end
end
