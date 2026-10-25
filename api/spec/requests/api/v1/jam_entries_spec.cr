require "../../../spec_helper"

describe Api::V1::Jams::Entries do
  describe "POST /api/v1/jams/:slug/entries" do
    it "submits a published project owned by the user" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id).status("published").published_at(Time.utc)
      jam = JamFactory.create &.status("published").published_at(Time.utc)

      response = AuthHelper.client_for(user).post("/api/v1/jams/#{jam.slug}/entries", jam_entry: {
        project_slug: project.slug,
      })

      response.status_code.should eq 201
      body = JSON.parse(response.body)
      body["status"].as_s.should eq "submitted"
      body["project"]["slug"].as_s.should eq project.slug
    end

    it "allows several projects from one account" do
      user = UserFactory.create
      first = ProjectFactory.create &.user_id(user.id).status("published").published_at(Time.utc)
      second = ProjectFactory.create &.user_id(user.id).status("published").published_at(Time.utc)
      jam = JamFactory.create &.status("published").published_at(Time.utc)
      client = AuthHelper.client_for(user)

      client.post("/api/v1/jams/#{jam.slug}/entries", jam_entry: {project_slug: first.slug})
        .status_code.should eq 201
      client.post("/api/v1/jams/#{jam.slug}/entries", jam_entry: {project_slug: second.slug})
        .status_code.should eq 201

      JamEntryQuery.new.for_jam(jam.id).for_user(user.id).select_count.should eq 2
    end

    it "rejects the same project twice" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id).status("published").published_at(Time.utc)
      jam = JamFactory.create &.status("published").published_at(Time.utc)
      client = AuthHelper.client_for(user)

      client.post("/api/v1/jams/#{jam.slug}/entries", jam_entry: {project_slug: project.slug})
        .status_code.should eq 201

      response = client.post("/api/v1/jams/#{jam.slug}/entries", jam_entry: {project_slug: project.slug})

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "already_submitted"
    end

    it "rejects a draft project" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)
      jam = JamFactory.create &.status("published").published_at(Time.utc)

      response = AuthHelper.client_for(user).post("/api/v1/jams/#{jam.slug}/entries", jam_entry: {
        project_slug: project.slug,
      })

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "project_not_published"
    end

    it "rejects somebody else's project" do
      user = UserFactory.create
      project = ProjectFactory.create &.status("published").published_at(Time.utc)
      jam = JamFactory.create &.status("published").published_at(Time.utc)

      response = AuthHelper.client_for(user).post("/api/v1/jams/#{jam.slug}/entries", jam_entry: {
        project_slug: project.slug,
      })

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "project_not_found"
    end

    it "rejects a submission after the deadline" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id).status("published").published_at(Time.utc)
      now = Time.utc
      jam = JamFactory.create &.status("published").published_at(now)
        .starts_at(now - 3.days).submissions_close_at(now - 2.days).voting_closes_at(now - 1.day)

      response = AuthHelper.client_for(user).post("/api/v1/jams/#{jam.slug}/entries", jam_entry: {
        project_slug: project.slug,
      })

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "jam_not_open"
    end

    it "requires a confirmed email" do
      user = UserFactory.create &.unconfirmed
      project = ProjectFactory.create &.user_id(user.id).status("published").published_at(Time.utc)
      jam = JamFactory.create &.status("published").published_at(Time.utc)

      response = AuthHelper.client_for(user).post("/api/v1/jams/#{jam.slug}/entries", jam_entry: {
        project_slug: project.slug,
      })

      response.status_code.should eq 403
      JSON.parse(response.body)["error"]["code"].as_s.should eq "email_not_confirmed"
    end

    it "shows the entry count and the viewer's entries on the jam page" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id).status("published").published_at(Time.utc)
      jam = JamFactory.create &.status("published").published_at(Time.utc)
      client = AuthHelper.client_for(user)

      client.post("/api/v1/jams/#{jam.slug}/entries", jam_entry: {project_slug: project.slug})
        .status_code.should eq 201

      response = client.get("/api/v1/jams/#{jam.slug}")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["entries_count"].as_i.should eq 1
      body["viewer"]["can_submit"].as_bool.should be_true
      body["viewer"]["my_entries"].as_a.size.should eq 1
    end
  end

  describe "GET /api/v1/jams/:slug/entries" do
    it "lists submitted entries with pagination" do
      jam = JamFactory.create &.status("published").published_at(Time.utc)
      3.times { JamEntryFactory.create &.jam_id(jam.id) }

      response = ApiClient.new.get("/api/v1/jams/#{jam.slug}/entries?per_page=2")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["items"].as_a.size.should eq 2
      body["meta"]["total"].as_i.should eq 3
      body["meta"]["pages"].as_i.should eq 2
    end

    it "hides disqualified entries from the public list" do
      jam = JamFactory.create &.status("published").published_at(Time.utc)
      visible = JamEntryFactory.create &.jam_id(jam.id)
      JamEntryFactory.create &.jam_id(jam.id).status("disqualified")

      response = ApiClient.new.get("/api/v1/jams/#{jam.slug}/entries")

      response.status_code.should eq 200
      items = JSON.parse(response.body)["items"].as_a
      items.map(&.["id"].as_i64).should eq [visible.id]
    end

    it "shows disqualified entries to the organizer" do
      user = UserFactory.create
      jam = JamFactory.create &.user_id(user.id).status("published").published_at(Time.utc)
      JamEntryFactory.create &.jam_id(jam.id)
      JamEntryFactory.create &.jam_id(jam.id).status("disqualified")

      response = AuthHelper.client_for(user).get("/api/v1/jams/#{jam.slug}/entries?status=all")

      response.status_code.should eq 200
      JSON.parse(response.body)["items"].as_a.size.should eq 2
    end

    it "hides an entry whose project was unpublished from the public list" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)
      jam = JamFactory.create &.status("published").published_at(Time.utc)
      JamEntryFactory.create &.jam_id(jam.id).project_id(project.id).user_id(user.id)

      ApiClient.new.get("/api/v1/jams/#{jam.slug}/entries").status_code.should eq 200
      JSON.parse(ApiClient.new.get("/api/v1/jams/#{jam.slug}/entries").body)["items"]
        .as_a.should be_empty

      owner_response = AuthHelper.client_for(user).get("/api/v1/jams/#{jam.slug}/entries")
      JSON.parse(owner_response.body)["items"].as_a.size.should eq 1
    end
  end

  describe "DELETE /api/v1/jams/:slug/entries/:id" do
    it "lets the author withdraw while submissions are open" do
      user = UserFactory.create
      jam = JamFactory.create &.status("published").published_at(Time.utc)
      entry = JamEntryFactory.create &.jam_id(jam.id).user_id(user.id)

      response = AuthHelper.client_for(user).delete("/api/v1/jams/#{jam.slug}/entries/#{entry.id}")

      response.status_code.should eq 204
      JamEntryQuery.new.id(entry.id).first?.should be_nil
    end

    it "does not let the author withdraw after the deadline" do
      user = UserFactory.create
      now = Time.utc
      jam = JamFactory.create &.status("published").published_at(now)
        .starts_at(now - 3.days).submissions_close_at(now - 2.days).voting_closes_at(now - 1.day)
      entry = JamEntryFactory.create &.jam_id(jam.id).user_id(user.id)

      response = AuthHelper.client_for(user).delete("/api/v1/jams/#{jam.slug}/entries/#{entry.id}")

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "entry_locked"
    end

    it "lets the organizer remove an entry after the deadline" do
      organizer = UserFactory.create
      now = Time.utc
      jam = JamFactory.create &.user_id(organizer.id).status("published").published_at(now)
        .starts_at(now - 3.days).submissions_close_at(now - 2.days).voting_closes_at(now - 1.day)
      entry = JamEntryFactory.create &.jam_id(jam.id)

      response = AuthHelper.client_for(organizer).delete("/api/v1/jams/#{jam.slug}/entries/#{entry.id}")

      response.status_code.should eq 204
    end
  end

  describe "disqualification" do
    it "disqualifies and restores an entry" do
      organizer = UserFactory.create
      jam = JamFactory.create &.user_id(organizer.id).status("published").published_at(Time.utc)
      entry = JamEntryFactory.create &.jam_id(jam.id)
      client = AuthHelper.client_for(organizer)

      response = client.post("/api/v1/jams/#{jam.slug}/entries/#{entry.id}/disqualify", jam_entry: {
        disqualified_reason: "Нарушены правила",
      })

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["status"].as_s.should eq "disqualified"
      body["disqualified_reason"].as_s.should eq "Нарушены правила"

      restored = client.post("/api/v1/jams/#{jam.slug}/entries/#{entry.id}/restore")

      restored.status_code.should eq 200
      JSON.parse(restored.body)["status"].as_s.should eq "submitted"
    end

    it "does not let a participant disqualify somebody else" do
      jam = JamFactory.create &.status("published").published_at(Time.utc)
      entry = JamEntryFactory.create &.jam_id(jam.id)

      response = AuthHelper.client_for(UserFactory.create).post(
        "/api/v1/jams/#{jam.slug}/entries/#{entry.id}/disqualify",
        jam_entry: {disqualified_reason: "Не нравится"},
      )

      response.status_code.should eq 404
    end
  end

  describe "GET /api/v1/jams/:slug/eligible_projects" do
    it "returns published projects without an entry in this jam" do
      user = UserFactory.create
      available = ProjectFactory.create &.user_id(user.id).status("published").published_at(Time.utc)
      entered = ProjectFactory.create &.user_id(user.id).status("published").published_at(Time.utc)
      ProjectFactory.create &.user_id(user.id)
      jam = JamFactory.create &.status("published").published_at(Time.utc)
      JamEntryFactory.create &.jam_id(jam.id).project_id(entered.id).user_id(user.id)

      response = AuthHelper.client_for(user).get("/api/v1/jams/#{jam.slug}/eligible_projects")

      response.status_code.should eq 200
      items = JSON.parse(response.body)["items"].as_a
      items.map(&.["slug"].as_s).should eq [available.slug]
    end

    it "rejects the picker after the deadline" do
      user = UserFactory.create
      now = Time.utc
      jam = JamFactory.create &.status("published").published_at(now)
        .starts_at(now - 3.days).submissions_close_at(now - 2.days).voting_closes_at(now - 1.day)

      response = AuthHelper.client_for(user).get("/api/v1/jams/#{jam.slug}/eligible_projects")

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "jam_not_open"
    end
  end

  describe "GET /api/v1/projects/:slug/jams" do
    it "lists the jams a project entered" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id).status("published").published_at(Time.utc)
      jam = JamFactory.create &.status("published").published_at(Time.utc)
      JamEntryFactory.create &.jam_id(jam.id).project_id(project.id).user_id(user.id)

      response = ApiClient.new.get("/api/v1/projects/#{project.slug}/jams")

      response.status_code.should eq 200
      items = JSON.parse(response.body)["items"].as_a
      items.size.should eq 1
      items.first["jam"]["slug"].as_s.should eq jam.slug
      items.first["status"].as_s.should eq "submitted"
    end

    it "hides disqualified entries from the public project page" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id).status("published").published_at(Time.utc)
      jam = JamFactory.create &.status("published").published_at(Time.utc)
      JamEntryFactory.create &.jam_id(jam.id).project_id(project.id).user_id(user.id)
        .status("disqualified")

      ApiClient.new.get("/api/v1/projects/#{project.slug}/jams").status_code.should eq 200
      JSON.parse(ApiClient.new.get("/api/v1/projects/#{project.slug}/jams").body)["items"]
        .as_a.should be_empty

      owner_response = AuthHelper.client_for(user).get("/api/v1/projects/#{project.slug}/jams")
      JSON.parse(owner_response.body)["items"].as_a.size.should eq 1
    end
  end
end
