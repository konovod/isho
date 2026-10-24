require "../../../../spec_helper"

describe Api::V1::Admin::Users::Impersonate do
  describe "POST /api/v1/admin/users/:username/impersonate" do
    it "starts a read-only view of another account" do
      admin = UserFactory.create &.is_admin(true)
      target = UserFactory.create &.email("target@example.com")
      admin_token = AuthHelper.token_for(admin)

      response = ApiClient.new.with_cookie(admin_token).post(
        "/api/v1/admin/users/#{target.username}/impersonate"
      )

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["username"].as_s.should eq target.username
      body["is_admin"].as_bool.should be_false
      body["impersonation"]["admin"]["username"].as_s.should eq admin.username

      act_as = cookie_value(response, Api::Auth::Helpers.impersonation_cookie_name)
      act_as.should_not be_nil

      # The target session works only next to the admin's own cookie.
      both = ApiClient.new.with_cookies({
        Api::Auth::Helpers.cookie_name               => admin_token,
        Api::Auth::Helpers.impersonation_cookie_name => act_as.not_nil!,
      })
      JSON.parse(both.get("/api/v1/me").body)["username"].as_s.should eq target.username

      ApiClient.new.with_cookie(act_as.not_nil!).get("/api/v1/me").status_code.should eq 401
    end

    it "uses the target's content preferences" do
      admin = UserFactory.create &.is_admin(true)
      target = UserFactory.create &.show_nsfw(false)
      ProjectFactory.create &.status("published").published_at(Time.utc).nsfw(true)
      admin_token = AuthHelper.token_for(admin)

      JSON.parse(AuthHelper.client_for(admin).get("/api/v1/projects").body)["items"].as_a.size.should eq 1

      response = ApiClient.new.with_cookie(admin_token).post(
        "/api/v1/admin/users/#{target.username}/impersonate"
      )
      act_as = cookie_value(response, Api::Auth::Helpers.impersonation_cookie_name).not_nil!
      client = ApiClient.new.with_cookies({
        Api::Auth::Helpers.cookie_name               => admin_token,
        Api::Auth::Helpers.impersonation_cookie_name => act_as,
      })

      JSON.parse(client.get("/api/v1/projects").body)["items"].as_a.should be_empty
    end

    it "forbids regular users" do
      target = UserFactory.create

      response = AuthHelper.client_for(UserFactory.create).post(
        "/api/v1/admin/users/#{target.username}/impersonate"
      )

      response.status_code.should eq 403
    end

    it "does not let an admin impersonate themselves or another admin" do
      admin = UserFactory.create &.is_admin(true)
      other_admin = UserFactory.create &.is_admin(true)
      client = AuthHelper.client_for(admin)

      client.post("/api/v1/admin/users/#{admin.username}/impersonate").status_code.should eq 422
      client.post("/api/v1/admin/users/#{other_admin.username}/impersonate").status_code.should eq 422
    end

    it "answers 404 for an unknown account" do
      admin = UserFactory.create &.is_admin(true)

      AuthHelper.client_for(admin).post("/api/v1/admin/users/nobody/impersonate").status_code.should eq 404
    end
  end

  describe "writes while impersonating" do
    it "rejects changes to the target account" do
      admin = UserFactory.create &.is_admin(true)
      target = UserFactory.create &.show_nsfw(true)
      admin_token = AuthHelper.token_for(admin)
      response = ApiClient.new.with_cookie(admin_token).post(
        "/api/v1/admin/users/#{target.username}/impersonate"
      )
      act_as = cookie_value(response, Api::Auth::Helpers.impersonation_cookie_name).not_nil!
      client = ApiClient.new.with_cookies({
        Api::Auth::Helpers.cookie_name               => admin_token,
        Api::Auth::Helpers.impersonation_cookie_name => act_as,
      })

      response = client.patch("/api/v1/me/preferences", user: {show_nsfw: false})

      response.status_code.should eq 403
      JSON.parse(response.body)["error"]["code"].as_s.should eq "impersonation_read_only"
      UserQuery.new.id(target.id).first.not_nil!.show_nsfw.should be_true
    end
  end

  describe "DELETE /api/v1/impersonation" do
    it "returns to the admin and drops the target session" do
      admin = UserFactory.create &.is_admin(true)
      target = UserFactory.create
      admin_token = AuthHelper.token_for(admin)
      response = ApiClient.new.with_cookie(admin_token).post(
        "/api/v1/admin/users/#{target.username}/impersonate"
      )
      act_as = cookie_value(response, Api::Auth::Helpers.impersonation_cookie_name).not_nil!
      client = ApiClient.new.with_cookies({
        Api::Auth::Helpers.cookie_name               => admin_token,
        Api::Auth::Helpers.impersonation_cookie_name => act_as,
      })

      response = client.delete("/api/v1/impersonation")

      response.status_code.should eq 200
      JSON.parse(response.body)["username"].as_s.should eq admin.username
      AuthSessionQuery.new.where("impersonator_id IS NOT NULL").select_count.should eq 0
    end

    it "ignores an expired view and still signs the admin back in" do
      admin = UserFactory.create &.is_admin(true)
      target = UserFactory.create
      _, stale = ::Auth::Session.start(
        target,
        ttl: -1.minute,
        impersonator_id: admin.id,
      )
      client = ApiClient.new.with_cookies({
        Api::Auth::Helpers.cookie_name               => AuthHelper.token_for(admin),
        Api::Auth::Helpers.impersonation_cookie_name => stale,
      })

      JSON.parse(client.get("/api/v1/me").body)["username"].as_s.should eq admin.username
    end

    it "ignores a view opened by another admin" do
      admin = UserFactory.create &.is_admin(true)
      other_admin = UserFactory.create &.is_admin(true)
      target = UserFactory.create
      _, token = ::Auth::Session.start(target, impersonator_id: other_admin.id)
      client = ApiClient.new.with_cookies({
        Api::Auth::Helpers.cookie_name               => AuthHelper.token_for(admin),
        Api::Auth::Helpers.impersonation_cookie_name => token,
      })

      JSON.parse(client.get("/api/v1/me").body)["username"].as_s.should eq admin.username
    end
  end
end

private def cookie_value(response : HTTP::Client::Response, name : String) : String?
  response.cookies.find { |cookie| cookie.name == name }.try(&.value)
end
