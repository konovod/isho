require "../../../spec_helper"

describe "Private messages" do
  describe "POST /api/v1/messages/:username" do
    it "stores a message and shows it to both sides" do
      alice = UserFactory.create
      bob = UserFactory.create

      response = AuthHelper.client_for(alice).post(
        "/api/v1/messages/#{bob.username}",
        private_message: {body: "Привет, **bob**"},
      )

      response.status_code.should eq 201
      created = JSON.parse(response.body)
      created["body"].as_s.should eq "Привет, **bob**"
      created["author"]["username"].as_s.should eq alice.username
      created["mine"].as_bool.should be_true

      alice_inbox = JSON.parse(AuthHelper.client_for(alice).get("/api/v1/messages").body)
      alice_inbox["unread_count"].as_i.should eq 0
      alice_inbox["items"].as_a.size.should eq 1
      alice_inbox["items"].as_a.first["peer"]["username"].as_s.should eq bob.username
      alice_inbox["items"].as_a.first["last_message"]["mine"].as_bool.should be_true

      bob_inbox = JSON.parse(AuthHelper.client_for(bob).get("/api/v1/messages").body)
      bob_inbox["unread_count"].as_i.should eq 1
      bob_inbox["items"].as_a.first["unread_count"].as_i.should eq 1

      chat = JSON.parse(AuthHelper.client_for(bob).get("/api/v1/messages/#{alice.username}").body)
      chat["peer"]["username"].as_s.should eq alice.username
      chat["items"].as_a.size.should eq 1
      chat["items"].as_a.first["mine"].as_bool.should be_false
    end

    it "keeps a conversation private to its two participants" do
      alice = UserFactory.create
      bob = UserFactory.create
      eve = UserFactory.create

      AuthHelper.client_for(alice).post(
        "/api/v1/messages/#{bob.username}",
        private_message: {body: "секрет"},
      )

      eve_chat = JSON.parse(AuthHelper.client_for(eve).get("/api/v1/messages/#{alice.username}").body)
      eve_chat["items"].as_a.should be_empty

      eve_inbox = JSON.parse(AuthHelper.client_for(eve).get("/api/v1/messages").body)
      eve_inbox["items"].as_a.should be_empty
      eve_inbox["unread_count"].as_i.should eq 0
    end

    it "requires a confirmed address" do
      alice = UserFactory.create &.email_confirmed_at(nil)
      bob = UserFactory.create

      response = AuthHelper.client_for(alice).post(
        "/api/v1/messages/#{bob.username}",
        private_message: {body: "Привет"},
      )

      response.status_code.should eq 403
      JSON.parse(response.body)["error"]["code"].as_s.should eq "email_not_confirmed"
      PrivateMessageQuery.new.select_count.should eq 0
    end

    it "rejects a banned sender" do
      admin = UserFactory.create &.is_admin(true)
      alice = UserFactory.create
      bob = UserFactory.create
      BanUser.run!(user: alice, moderator: admin, reason: "Спам", days: 3)

      response = AuthHelper.client_for(alice).post(
        "/api/v1/messages/#{bob.username}",
        private_message: {body: "Привет"},
      )

      response.status_code.should eq 403
      JSON.parse(response.body)["error"]["code"].as_s.should eq "user_banned"
      PrivateMessageQuery.new.select_count.should eq 0
    end

    it "rejects an empty message" do
      alice = UserFactory.create
      bob = UserFactory.create

      response = AuthHelper.client_for(alice).post(
        "/api/v1/messages/#{bob.username}",
        private_message: {body: "   "},
      )

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["details"]["body"].as_a.first.as_s.should eq "is required"
    end

    it "rejects a message over the limit" do
      alice = UserFactory.create
      bob = UserFactory.create
      body = "a" * (AppSettings::PRIVATE_MESSAGE_MAX_CHARS + 1)

      response = AuthHelper.client_for(alice).post(
        "/api/v1/messages/#{bob.username}",
        private_message: {body: body},
      )

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["details"]["body"].as_a.first.as_s.should eq(
        "must not have more than #{AppSettings::PRIVATE_MESSAGE_MAX_CHARS} characters"
      )
    end

    it "does not let an account write to itself" do
      alice = UserFactory.create

      response = AuthHelper.client_for(alice).post(
        "/api/v1/messages/#{alice.username}",
        private_message: {body: "Привет"},
      )

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "cannot_message_self"
      PrivateMessageQuery.new.select_count.should eq 0
    end

    it "returns 404 for an unknown account" do
      alice = UserFactory.create

      response = AuthHelper.client_for(alice).post(
        "/api/v1/messages/nobody",
        private_message: {body: "Привет"},
      )

      response.status_code.should eq 404
    end

    it "requires authentication" do
      bob = UserFactory.create

      response = ApiClient.new.post(
        "/api/v1/messages/#{bob.username}",
        private_message: {body: "Привет"},
      )

      response.status_code.should eq 401
      JSON.parse(response.body)["error"]["code"].as_s.should eq "unauthorized"
    end

    it "stops a sender after the per-minute limit" do
      alice = UserFactory.create
      bob = UserFactory.create
      client = AuthHelper.client_for(alice)

      AppSettings::PRIVATE_MESSAGES_PER_MINUTE.times do |index|
        response = client.post(
          "/api/v1/messages/#{bob.username}",
          private_message: {body: "Сообщение #{index}"},
        )
        response.status_code.should eq 201
      end

      limited = client.post(
        "/api/v1/messages/#{bob.username}",
        private_message: {body: "Лишнее"},
      )

      limited.status_code.should eq 429
      JSON.parse(limited.body)["error"]["code"].as_s.should eq "too_many_requests"
      PrivateMessageQuery.new.select_count.should eq AppSettings::PRIVATE_MESSAGES_PER_MINUTE
    end
  end

  describe "GET /api/v1/messages/:username" do
    it "pages the history backwards and fetches newer messages forward" do
      alice = UserFactory.create
      bob = UserFactory.create
      client = AuthHelper.client_for(bob)
      messages = [] of PrivateMessage

      55.times do |index|
        messages << PrivateMessageFactory.create do |factory|
          factory.sender_id(alice.id)
          factory.recipient_id(bob.id)
          factory.body("Сообщение #{index}")
        end
      end

      page = JSON.parse(client.get("/api/v1/messages/#{alice.username}").body)
      page["items"].as_a.size.should eq 50
      page["has_more"].as_bool.should be_true
      page["items"].as_a.first["id"].as_i64.should eq messages[5].id
      page["items"].as_a.last["id"].as_i64.should eq messages[54].id

      older = JSON.parse(client.get("/api/v1/messages/#{alice.username}?before=#{messages[5].id}").body)
      older["items"].as_a.size.should eq 5
      older["has_more"].as_bool.should be_false
      older["items"].as_a.first["id"].as_i64.should eq messages[0].id

      fresh = PrivateMessageFactory.create &.sender_id(alice.id).recipient_id(bob.id).body("Новое")
      newer = JSON.parse(client.get("/api/v1/messages/#{alice.username}?after=#{messages[54].id}").body)
      newer["items"].as_a.size.should eq 1
      newer["items"].as_a.first["id"].as_i64.should eq fresh.id
    end

    it "returns 404 for a missing account and for the account itself" do
      alice = UserFactory.create
      client = AuthHelper.client_for(alice)

      client.get("/api/v1/messages/nobody").status_code.should eq 404
      client.get("/api/v1/messages/#{alice.username}").status_code.should eq 404
    end
  end

  describe "POST /api/v1/messages/:username/read" do
    it "marks incoming messages read and updates the header counter" do
      alice = UserFactory.create
      bob = UserFactory.create
      client = AuthHelper.client_for(bob)
      PrivateMessageFactory.create &.sender_id(alice.id).recipient_id(bob.id)
      PrivateMessageFactory.create &.sender_id(alice.id).recipient_id(bob.id)

      JSON.parse(client.get("/api/v1/me").body)["unread_messages_count"].as_i.should eq 2

      response = client.post("/api/v1/messages/#{alice.username}/read")

      response.status_code.should eq 200
      JSON.parse(response.body)["unread_count"].as_i.should eq 0
      JSON.parse(client.get("/api/v1/me").body)["unread_messages_count"].as_i.should eq 0
      PrivateMessageQuery.new.unread.select_count.should eq 0
    end

    it "keeps messages from other accounts unread" do
      alice = UserFactory.create
      bob = UserFactory.create
      carol = UserFactory.create
      client = AuthHelper.client_for(bob)
      PrivateMessageFactory.create &.sender_id(alice.id).recipient_id(bob.id)
      PrivateMessageFactory.create &.sender_id(carol.id).recipient_id(bob.id)

      client.post("/api/v1/messages/#{alice.username}/read")

      JSON.parse(client.get("/api/v1/me").body)["unread_messages_count"].as_i.should eq 1
    end

    it "is a write and is rejected while an admin views the account" do
      admin = UserFactory.create &.is_admin(true)
      alice = UserFactory.create
      bob = UserFactory.create
      PrivateMessageFactory.create &.sender_id(alice.id).recipient_id(bob.id)
      admin_token = AuthHelper.token_for(admin)

      response = ApiClient.new.with_cookie(admin_token).post(
        "/api/v1/admin/users/#{bob.username}/impersonate"
      )
      act_as = message_cookie_value(response, Api::Auth::Helpers.impersonation_cookie_name).not_nil!
      client = ApiClient.new.with_cookies({
        Api::Auth::Helpers.cookie_name               => admin_token,
        Api::Auth::Helpers.impersonation_cookie_name => act_as,
      })

      client.post("/api/v1/messages/#{alice.username}/read").status_code.should eq 403
      client.post(
        "/api/v1/messages/#{alice.username}",
        private_message: {body: "Ответ"},
      ).status_code.should eq 403

      PrivateMessageQuery.new.unread.select_count.should eq 1
    end
  end
end

private def message_cookie_value(response : HTTP::Client::Response, name : String) : String?
  response.cookies.find { |cookie| cookie.name == name }.try(&.value)
end
