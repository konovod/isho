require "../../../../spec_helper"

describe Api::V1::Admin::Projects do
  describe "POST /api/v1/admin/projects/:slug/unpublish" do
    it "unpublishes the project with a reason and shows it to the author" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create
      project = ProjectFactory.create &.user_id(author.id).status("published").published_at(Time.utc)

      response = AuthHelper.client_for(admin).post(
        "/api/v1/admin/projects/#{project.slug}/unpublish",
        project: {moderation_note: "Нарушает правила"},
      )

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["status"].as_s.should eq "draft"
      body["moderation_note"].as_s.should eq "Нарушает правила"

      updated = ProjectQuery.new.id(project.id).first?.not_nil!
      updated.status.should eq "draft"
      updated.published_at.should be_nil
      updated.moderation_note.should eq "Нарушает правила"
      updated.moderated_by_id.should eq admin.id
      updated.moderated_at.should_not be_nil

      author_response = AuthHelper.client_for(author).get("/api/v1/projects/#{project.slug}")

      author_response.status_code.should eq 200
      JSON.parse(author_response.body)["moderation_note"].as_s.should eq "Нарушает правила"
    end

    it "requires a reason" do
      admin = UserFactory.create &.is_admin(true)
      project = ProjectFactory.create &.status("published").published_at(Time.utc)

      response = AuthHelper.client_for(admin).post(
        "/api/v1/admin/projects/#{project.slug}/unpublish",
        project: {moderation_note: "   "},
      )

      response.status_code.should eq 422
      ProjectQuery.new.id(project.id).first?.not_nil!.status.should eq "published"
    end

    it "rejects reasons longer than 500 characters" do
      admin = UserFactory.create &.is_admin(true)
      project = ProjectFactory.create &.status("published").published_at(Time.utc)

      response = AuthHelper.client_for(admin).post(
        "/api/v1/admin/projects/#{project.slug}/unpublish",
        project: {moderation_note: "а" * 501},
      )

      response.status_code.should eq 422
      ProjectQuery.new.id(project.id).first?.not_nil!.status.should eq "published"
    end

    it "does not unpublish a project that is already a draft" do
      admin = UserFactory.create &.is_admin(true)
      project = ProjectFactory.create

      response = AuthHelper.client_for(admin).post(
        "/api/v1/admin/projects/#{project.slug}/unpublish",
        project: {moderation_note: "Причина"},
      )

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "not_published"
    end

    it "forbids regular users" do
      author = UserFactory.create
      project = ProjectFactory.create &.user_id(author.id).status("published").published_at(Time.utc)

      response = AuthHelper.client_for(author).post(
        "/api/v1/admin/projects/#{project.slug}/unpublish",
        project: {moderation_note: "Причина"},
      )

      response.status_code.should eq 403
      ProjectQuery.new.id(project.id).first?.not_nil!.status.should eq "published"
    end

    it "keeps the reason out of public project responses" do
      project = ProjectFactory.create &.status("published").published_at(Time.utc)
      Project::SaveOperation.update!(
        project,
        moderation_note: "Служебная заметка",
        moderated_at: Time.utc,
      )

      response = ApiClient.new.get("/api/v1/projects/#{project.slug}")

      response.status_code.should eq 200
      body = JSON.parse(response.body).as_h
      body.has_key?("moderation_note").should be_false
      body.has_key?("moderated_at").should be_false
    end

    it "clears the reason when the author publishes the project again" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create
      project = ProjectFactory.create &.user_id(author.id).status("published").published_at(Time.utc)

      AuthHelper.client_for(admin).post(
        "/api/v1/admin/projects/#{project.slug}/unpublish",
        project: {moderation_note: "Нарушает правила"},
      )

      response = AuthHelper.client_for(author).post("/api/v1/projects/#{project.slug}/publish")

      response.status_code.should eq 200
      JSON.parse(response.body)["moderation_note"].raw.should be_nil

      updated = ProjectQuery.new.id(project.id).first?.not_nil!
      updated.status.should eq "published"
      updated.moderation_note.should be_nil
      updated.moderated_at.should be_nil
      updated.moderated_by_id.should be_nil
    end
  end
end
