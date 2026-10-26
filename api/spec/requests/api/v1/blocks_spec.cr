require "../../../spec_helper"

describe "Blacklist" do
  describe "POST /api/v1/users/:username/block" do
    it "blocks an account, idempotently" do
      alice = UserFactory.create
      bob = UserFactory.create
      client = AuthHelper.client_for(alice)

      response = client.post("/api/v1/users/#{bob.username}/block")
      response.status_code.should eq 200
      JSON.parse(response.body)["blocked"].as_bool.should be_true

      client.post("/api/v1/users/#{bob.username}/block").status_code.should eq 200
      UserBlockQuery.new.blocker(alice.id).blocked_user(bob.id).select_count.should eq 1
    end

    it "does not let an account block itself" do
      alice = UserFactory.create

      response = AuthHelper.client_for(alice).post("/api/v1/users/#{alice.username}/block")

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "cannot_block_self"
      UserBlockQuery.new.select_count.should eq 0
    end

    it "requires authentication and an existing account" do
      bob = UserFactory.create

      ApiClient.new.post("/api/v1/users/#{bob.username}/block").status_code.should eq 401
      AuthHelper.client_for(UserFactory.create).post("/api/v1/users/nobody/block").status_code.should eq 404
    end

    it "shows the flag only to the blocker" do
      alice = UserFactory.create
      bob = UserFactory.create

      AuthHelper.client_for(alice).post("/api/v1/users/#{bob.username}/block")

      alice_view = JSON.parse(AuthHelper.client_for(alice).get("/api/v1/users/#{bob.username}").body)
      alice_view["blocked"].as_bool.should be_true

      bob_view = JSON.parse(AuthHelper.client_for(bob).get("/api/v1/users/#{alice.username}").body)
      bob_view["blocked"].as_bool.should be_false

      guest_view = JSON.parse(ApiClient.new.get("/api/v1/users/#{alice.username}").body)
      guest_view["blocked"].as_bool.should be_false
    end

    it "is rejected while an admin views the account" do
      admin = UserFactory.create &.is_admin(true)
      bob = UserFactory.create
      admin_token = AuthHelper.token_for(admin)

      response = ApiClient.new.with_cookie(admin_token).post(
        "/api/v1/admin/users/#{bob.username}/impersonate"
      )
      act_as = block_cookie_value(response, Api::Auth::Helpers.impersonation_cookie_name).not_nil!
      client = ApiClient.new.with_cookies({
        Api::Auth::Helpers.cookie_name               => admin_token,
        Api::Auth::Helpers.impersonation_cookie_name => act_as,
      })

      client.post("/api/v1/users/#{UserFactory.create.username}/block").status_code.should eq 403
    end
  end

  describe "GET /api/v1/me/blocked_users and DELETE" do
    it "lists and unblocks the current user's blacklist" do
      alice = UserFactory.create
      bob = UserFactory.create
      carol = UserFactory.create
      UserBlockFactory.create &.blocker_id(alice.id).blocked_user_id(bob.id)

      list = JSON.parse(AuthHelper.client_for(alice).get("/api/v1/me/blocked_users").body)
      list["items"].as_a.size.should eq 1
      list["items"].as_a.first["user"]["username"].as_s.should eq bob.username

      carol_list = JSON.parse(AuthHelper.client_for(carol).get("/api/v1/me/blocked_users").body)
      carol_list["items"].as_a.should be_empty

      response = AuthHelper.client_for(alice).delete("/api/v1/users/#{bob.username}/block")
      response.status_code.should eq 200
      JSON.parse(response.body)["blocked"].as_bool.should be_false

      JSON.parse(AuthHelper.client_for(alice).get("/api/v1/me/blocked_users").body)["items"].as_a.should be_empty
      # Unblocking again is harmless.
      AuthHelper.client_for(alice).delete("/api/v1/users/#{bob.username}/block").status_code.should eq 200
    end
  end

  describe "private messages" do
    it "accepts a message to a blocker silently but never delivers it" do
      alice = UserFactory.create
      bob = UserFactory.create
      UserBlockFactory.create &.blocker_id(alice.id).blocked_user_id(bob.id)

      response = AuthHelper.client_for(bob).post(
        "/api/v1/messages/#{alice.username}",
        private_message: {body: "Привет"},
      )

      response.status_code.should eq 201
      JSON.parse(response.body)["mine"].as_bool.should be_true
      message = PrivateMessageQuery.new.first?.not_nil!
      message.delivered.should be_false

      alice_inbox = JSON.parse(AuthHelper.client_for(alice).get("/api/v1/messages").body)
      alice_inbox["items"].as_a.should be_empty
      alice_inbox["unread_count"].as_i.should eq 0
      JSON.parse(AuthHelper.client_for(alice).get("/api/v1/me").body)["unread_messages_count"].as_i.should eq 0

      alice_chat = JSON.parse(AuthHelper.client_for(alice).get("/api/v1/messages/#{bob.username}").body)
      alice_chat["items"].as_a.should be_empty
      alice_chat["blocked"].as_bool.should be_true

      # The sender keeps the message in their own history and does not learn
      # that it was not delivered.
      bob_chat = JSON.parse(AuthHelper.client_for(bob).get("/api/v1/messages/#{alice.username}").body)
      bob_chat["items"].as_a.size.should eq 1
      bob_chat["blocked"].as_bool.should be_false
    end

    it "closes the conversation for both sides" do
      alice = UserFactory.create
      bob = UserFactory.create
      client = AuthHelper.client_for(alice)
      client.post("/api/v1/users/#{bob.username}/block")

      response = client.post(
        "/api/v1/messages/#{bob.username}",
        private_message: {body: "Ответ"},
      )

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "blocked_peer"
      PrivateMessageQuery.new.select_count.should eq 0
    end

    it "keeps the history but clears the unread counter on block" do
      alice = UserFactory.create
      bob = UserFactory.create
      old = PrivateMessageFactory.create &.sender_id(bob.id).recipient_id(alice.id)
      PrivateMessageFactory.create &.sender_id(bob.id).recipient_id(alice.id)

      JSON.parse(AuthHelper.client_for(alice).get("/api/v1/me").body)["unread_messages_count"].as_i.should eq 2

      AuthHelper.client_for(alice).post("/api/v1/users/#{bob.username}/block")

      JSON.parse(AuthHelper.client_for(alice).get("/api/v1/me").body)["unread_messages_count"].as_i.should eq 0
      PrivateMessageQuery.new.unread.select_count.should eq 0

      chat = JSON.parse(AuthHelper.client_for(alice).get("/api/v1/messages/#{bob.username}").body)
      chat["items"].as_a.size.should eq 2
      chat["items"].as_a.first["id"].as_i64.should eq old.id
    end
  end
end

private def block_cookie_value(response : HTTP::Client::Response, name : String) : String?
  response.headers["Set-Cookie"]?.try do |header|
    header.split(';').first.split('=', 2)[1]? if header.starts_with?("#{name}=")
  end
end
