require "../../../../spec_helper"

describe Api::V1::Admin::Users::Ban do
  describe "POST /api/v1/admin/users/:username/ban" do
    it "bans a user and keeps projects, topics and posts" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create
      project = ProjectFactory.create &.user_id(author.id).status("published").published_at(Time.utc)
      topic = ForumTopicFactory.create &.user_id(author.id)
      post = ForumPostFactory.create &.user_id(author.id).topic_id(topic.id)

      response = AuthHelper.client_for(admin).post(
        "/api/v1/admin/users/#{author.username}/ban",
        ban: {reason: "Спам и оскорбления", days: 7},
      )

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["ban"]["reason"].as_s.should eq "Спам и оскорбления"
      body["ban"]["days_left"].as_i.should eq 7

      UserQuery.new.id(author.id).first?.should_not be_nil
      ProjectQuery.new.id(project.id).first?.should_not be_nil
      ForumTopicQuery.new.id(topic.id).first?.should_not be_nil
      ForumPostQuery.new.id(post.id).first?.should_not be_nil

      ban = UserBanQuery.new.for_user(author.id).active.first?
      ban.should_not be_nil
      ban.not_nil!.banned_by_id.should eq admin.id
    end

    it "lets a banned user sign in and shows the ban" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create

      AuthHelper.client_for(admin).post(
        "/api/v1/admin/users/#{author.username}/ban",
        ban: {reason: "Флуд", days: 3},
      )

      response = ApiClient.new.post(
        "/api/v1/sign_ins",
        user: {login: author.username, password: "password1234"},
      )

      response.status_code.should eq 200
      JSON.parse(response.body)["ban"]["reason"].as_s.should eq "Флуд"
    end

    it "reports the ban in /me and blocks publishing" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create
      client = AuthHelper.client_for(author)

      AuthHelper.client_for(admin).post(
        "/api/v1/admin/users/#{author.username}/ban",
        ban: {reason: "Спам", days: 2},
      )

      me = client.get("/api/v1/me")
      me.status_code.should eq 200
      JSON.parse(me.body)["ban"]["reason"].as_s.should eq "Спам"

      create = client.post("/api/v1/projects", project: {title: "Новый проект", kind: "game"})
      create.status_code.should eq 403
      JSON.parse(create.body)["error"]["code"].as_s.should eq "user_banned"

      ForumSectionFactory.create &.slug("site")
      topic = client.post(
        "/api/v1/forum/sections/site/topics",
        forum_topic: {title: "Тема", body: "Текст"},
      )
      topic.status_code.should eq 403
      JSON.parse(topic.body)["error"]["code"].as_s.should eq "user_banned"
    end

    it "allows profile and theme changes but blocks project edits" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create
      project = ProjectFactory.create &.user_id(author.id)
      AuthHelper.client_for(admin).post(
        "/api/v1/admin/users/#{author.username}/ban",
        ban: {reason: "Спам", days: 2},
      )
      client = AuthHelper.client_for(author)

      profile = client.patch("/api/v1/me", user: {display_name: "Новое имя"})
      profile.status_code.should eq 200

      theme = client.patch("/api/v1/me/theme", user: {theme: "light"})
      theme.status_code.should eq 200

      edit = client.patch(
        "/api/v1/projects/#{project.slug}",
        project: {title: "Изменённое название"},
      )
      edit.status_code.should eq 403
      JSON.parse(edit.body)["error"]["code"].as_s.should eq "user_banned"
      ProjectQuery.new.id(project.id).first?.not_nil!.title.should_not eq "Изменённое название"
    end

    it "allows publishing again after the ban expires" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create
      UserBan::SaveOperation.create!(
        user_id: author.id,
        banned_by_id: admin.id,
        reason: "Старый бан",
        expires_at: Time.utc - 1.day,
      )

      response = AuthHelper.client_for(author).post(
        "/api/v1/projects",
        project: {title: "Снова можно", kind: "game"},
      )

      response.status_code.should eq 201
    end

    it "replaces an active ban and keeps the previous one in the history" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create
      client = AuthHelper.client_for(admin)

      client.post(
        "/api/v1/admin/users/#{author.username}/ban",
        ban: {reason: "Первый", days: 1},
      )
      client.post(
        "/api/v1/admin/users/#{author.username}/ban",
        ban: {reason: "Второй", days: 5},
      )

      bans = UserBanQuery.new.for_user(author.id).newest_first.results
      bans.size.should eq 2
      bans.count(&.active?).should eq 1
      bans.first.reason.should eq "Второй"
    end

    it "validates the reason and the term" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create
      client = AuthHelper.client_for(admin)

      blank = client.post(
        "/api/v1/admin/users/#{author.username}/ban",
        ban: {reason: "  ", days: 7},
      )
      blank.status_code.should eq 422
      JSON.parse(blank.body)["error"]["details"]["reason"].as_a.should_not be_empty

      zero = client.post(
        "/api/v1/admin/users/#{author.username}/ban",
        ban: {reason: "Причина", days: 0},
      )
      zero.status_code.should eq 422
      JSON.parse(zero.body)["error"]["details"]["days"].as_a.should_not be_empty

      too_long = client.post(
        "/api/v1/admin/users/#{author.username}/ban",
        ban: {reason: "Причина", days: 4000},
      )
      too_long.status_code.should eq 422
      UserBanQuery.new.for_user(author.id).select_count.should eq 0
    end

    it "does not let an admin ban themselves or another admin" do
      admin = UserFactory.create &.is_admin(true)
      other_admin = UserFactory.create &.is_admin(true)
      client = AuthHelper.client_for(admin)

      self_ban = client.post(
        "/api/v1/admin/users/#{admin.username}/ban",
        ban: {reason: "Причина", days: 1},
      )
      self_ban.status_code.should eq 422
      JSON.parse(self_ban.body)["error"]["code"].as_s.should eq "cannot_ban_self"

      admin_ban = client.post(
        "/api/v1/admin/users/#{other_admin.username}/ban",
        ban: {reason: "Причина", days: 1},
      )
      admin_ban.status_code.should eq 422
      JSON.parse(admin_ban.body)["error"]["code"].as_s.should eq "cannot_ban_admin"
    end

    it "forbids regular users" do
      author = UserFactory.create
      stranger = UserFactory.create

      response = AuthHelper.client_for(stranger).post(
        "/api/v1/admin/users/#{author.username}/ban",
        ban: {reason: "Причина", days: 1},
      )

      response.status_code.should eq 403
      UserBanQuery.new.for_user(author.id).select_count.should eq 0
    end
  end

  describe "DELETE /api/v1/admin/users/:username/ban" do
    it "lifts the active ban and lets the user publish again" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create
      ban = UserBan::SaveOperation.create!(
        user_id: author.id,
        banned_by_id: admin.id,
        reason: "Ошибка модератора",
        expires_at: 30.days.from_now,
      )

      response = AuthHelper.client_for(admin).delete("/api/v1/admin/users/#{author.username}/ban")

      response.status_code.should eq 200
      JSON.parse(response.body)["ban"].raw.should be_nil

      lifted = UserBanQuery.new.id(ban.id).first?.not_nil!
      lifted.lifted_at.should_not be_nil
      lifted.lifted_by_id.should eq admin.id

      create = AuthHelper.client_for(author).post(
        "/api/v1/projects",
        project: {title: "Снова можно", kind: "game"},
      )
      create.status_code.should eq 201
    end
  end

  describe "GET /api/v1/admin/users/:username/bans" do
    it "returns the ban history with moderators" do
      admin = UserFactory.create &.is_admin(true)
      author = UserFactory.create
      old = UserBan::SaveOperation.create!(
        user_id: author.id,
        banned_by_id: admin.id,
        reason: "Старый",
        expires_at: Time.utc - 1.day,
      )
      current = UserBan::SaveOperation.create!(
        user_id: author.id,
        banned_by_id: admin.id,
        reason: "Текущий",
        expires_at: 5.days.from_now,
      )

      response = AuthHelper.client_for(admin).get("/api/v1/admin/users/#{author.username}/bans")

      response.status_code.should eq 200
      items = JSON.parse(response.body)["items"].as_a
      items.size.should eq 2
      items.first["id"].as_i64.should eq current.id
      items.first["active"].as_bool.should be_true
      items.first["banned_by"].as_s.should eq admin.username
      items.last["id"].as_i64.should eq old.id
      items.last["active"].as_bool.should be_false
    end

    it "forbids regular users" do
      author = UserFactory.create

      response = AuthHelper.client_for(UserFactory.create).get("/api/v1/admin/users/#{author.username}/bans")

      response.status_code.should eq 403
    end
  end
end
