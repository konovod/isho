require "../../../../spec_helper"

describe Api::V1::Admin::Users do
  describe "GET /api/v1/admin/users" do
    it "lists users with project counts for an admin" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create &.email("author@example.com")
      ProjectFactory.create &.user_id(author.id)

      response = AuthHelper.client_for(admin).get("/api/v1/admin/users")

      response.status_code.should eq 200
      items = JSON.parse(response.body)["items"].as_a
      item = items.find { |entry| entry["id"].as_i64 == author.id }.not_nil!
      item["email"].as_s.should eq "author@example.com"
      item["projects_count"].as_i64.should eq 1
    end

    it "searches by email or username" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create &.email("findme@example.com")

      response = AuthHelper.client_for(admin).get("/api/v1/admin/users?q=findme")

      response.status_code.should eq 200
      JSON.parse(response.body)["items"].as_a.map(&.["id"].as_i64).should contain author.id
    end

    it "forbids regular users" do
      response = AuthHelper.client_for(UserFactory.create).get("/api/v1/admin/users")

      response.status_code.should eq 403
    end
  end

  describe "DELETE /api/v1/admin/users/:username" do
    it "deletes the user with projects, sessions and orphan tags" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create
      project = ProjectFactory.create &.user_id(author.id)
      orphan = Tag::SaveOperation.create!(name: "Lonely", slug: "lonely")
      ProjectTag::SaveOperation.create!(project_id: project.id, tag_id: orphan.id)
      AuthHelper.token_for(author)

      response = AuthHelper.client_for(admin).delete("/api/v1/admin/users/#{author.username}")

      response.status_code.should eq 204
      UserQuery.new.id(author.id).first?.should be_nil
      ProjectQuery.new.id(project.id).first?.should be_nil
      TagQuery.new.id(orphan.id).first?.should be_nil
      AuthSessionQuery.new.user_id(author.id).select_count.should eq 0

      blocked = BlockedEmailQuery.new.by_email(author.email).first?
      blocked.should_not be_nil
      blocked.not_nil!.username.should eq author.username
    end

    it "blacklists the email regardless of its case" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create &.email("Deleted@Example.com")

      response = AuthHelper.client_for(admin).delete("/api/v1/admin/users/#{author.username}")

      response.status_code.should eq 204
      BlockedEmailQuery.new.by_email("deleted@example.com").first?.should_not be_nil
    end

    it "keeps tags that other projects still use" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create
      project = ProjectFactory.create &.user_id(author.id)
      other_project = ProjectFactory.create
      shared = Tag::SaveOperation.create!(name: "Shared", slug: "shared")

      ProjectTag::SaveOperation.create!(project_id: project.id, tag_id: shared.id)
      ProjectTag::SaveOperation.create!(project_id: other_project.id, tag_id: shared.id)

      response = AuthHelper.client_for(admin).delete("/api/v1/admin/users/#{author.username}")

      response.status_code.should eq 204
      TagQuery.new.id(shared.id).first?.should_not be_nil
      ProjectTagQuery.new.project_id(other_project.id).select_count.should eq 1
    end

    it "recalculates topics the deleted user replied to" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create
      topic = ForumTopicFactory.create
      first = ForumPostFactory.create &.topic_id(topic.id).created_at(Time.utc - 1.hour)
      reply = ForumPostFactory.create &.topic_id(topic.id).user_id(author.id).created_at(Time.utc)
      ForumTopic::SaveOperation.update!(topic, replies_count: 1, last_post_at: reply.created_at)

      response = AuthHelper.client_for(admin).delete("/api/v1/admin/users/#{author.username}")

      response.status_code.should eq 204
      reloaded = ForumTopicQuery.new.id(topic.id).first?.not_nil!
      reloaded.replies_count.should eq 0
      reloaded.last_post_at.should eq first.created_at
    end

    it "does not let an admin delete their own account" do
      admin = UserFactory.create &.is_admin(true)

      response = AuthHelper.client_for(admin).delete("/api/v1/admin/users/#{admin.username}")

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "cannot_delete_self"
      UserQuery.new.id(admin.id).first?.should_not be_nil
    end

    it "forbids regular users" do
      author = UserFactory.create
      stranger = UserFactory.create

      response = AuthHelper.client_for(stranger).delete("/api/v1/admin/users/#{author.username}")

      response.status_code.should eq 403
      UserQuery.new.id(author.id).first?.should_not be_nil
    end
  end
end
