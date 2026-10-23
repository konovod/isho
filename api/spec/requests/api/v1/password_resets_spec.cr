require "../../../spec_helper"

describe Api::V1::PasswordResets do
  describe "POST /api/v1/password_resets" do
    it "sends a reset link to a known address" do
      user = UserFactory.create

      response = ApiClient.new.post("/api/v1/password_resets", user: {email: user.email.upcase})

      response.status_code.should eq 200
      JSON.parse(response.body)["sent"].as_bool.should be_true
      Carbon::DevAdapter.delivered_emails.size.should eq 1
      Carbon::DevAdapter.delivered_emails.last.should be_a PasswordResetEmail
      UserQuery.new.id(user.id).first?.not_nil!.password_reset_token_hash.should_not be_nil
    end

    it "answers the same way for an unknown address and sends nothing" do
      known = UserFactory.create
      known_response = ApiClient.new.post("/api/v1/password_resets", user: {email: known.email})

      response = ApiClient.new.post("/api/v1/password_resets", user: {email: "nobody@example.com"})

      response.status_code.should eq known_response.status_code
      response.body.should eq known_response.body
      Carbon::DevAdapter.delivered_emails.size.should eq 1
      Carbon::DevAdapter.delivered_emails.last.to.first.address.should eq known.email
    end

    it "does not send a second letter during the cooldown" do
      user = UserFactory.create
      client = ApiClient.new

      client.post("/api/v1/password_resets", user: {email: user.email}).status_code.should eq 200
      client.post("/api/v1/password_resets", user: {email: user.email}).status_code.should eq 200

      Carbon::DevAdapter.delivered_emails.size.should eq 1
    end

    it "requires an email" do
      response = ApiClient.new.post("/api/v1/password_resets", user: {email: ""})

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "validation_failed"
    end
  end

  describe "POST /api/v1/password_resets/:token" do
    it "sets a short password without digits or symbols, confirms the email and signs in" do
      user = UserFactory.create &.unconfirmed
      EmailConfirmation.issue(user)
      ApiClient.new.post("/api/v1/password_resets", user: {email: user.email})
      token = link_token_from_last_email

      response = ApiClient.new.post("/api/v1/password_resets/#{token}", user: {
        password:              "abcdef",
        password_confirmation: "abcdef",
      })

      response.status_code.should eq 200
      response.headers["Set-Cookie"].should contain "isho_auth="

      body = JSON.parse(response.body)
      body["username"].as_s.should eq user.username
      body["email_confirmed"].as_bool.should be_true

      updated = UserQuery.new.id(user.id).first?.not_nil!
      updated.password_reset_token_hash.should be_nil
      updated.password_reset_sent_at.should be_nil
      # A pending confirmation letter is obsolete: the reset link already
      # proved control of the mailbox.
      updated.email_confirmation_token_hash.should be_nil
      updated.email_confirmation_sent_at.should be_nil
      Authentic.correct_password?(updated, "abcdef").should be_true
      Authentic.correct_password?(updated, "password1234").should be_false
    end

    it "accepts the link only once" do
      user = UserFactory.create
      ApiClient.new.post("/api/v1/password_resets", user: {email: user.email})
      token = link_token_from_last_email

      first = ApiClient.new.post("/api/v1/password_resets/#{token}", user: {
        password:              "abcdef",
        password_confirmation: "abcdef",
      })
      first.status_code.should eq 200

      second = ApiClient.new.post("/api/v1/password_resets/#{token}", user: {
        password:              "ghijkl",
        password_confirmation: "ghijkl",
      })
      second.status_code.should eq 422
      JSON.parse(second.body)["error"]["code"].as_s.should eq "invalid_token"
    end

    it "rejects an expired link" do
      user = UserFactory.create
      token = PasswordReset.issue(user)
      SavePasswordReset.update!(
        user,
        password_reset_sent_at: (AppSettings::PASSWORD_RESET_TTL + 1.hour).ago,
      )

      response = ApiClient.new.post("/api/v1/password_resets/#{token}", user: {
        password:              "abcdef",
        password_confirmation: "abcdef",
      })

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "invalid_token"
      Authentic.correct_password?(UserQuery.new.id(user.id).first?.not_nil!, "password1234").should be_true
    end

    it "rejects an unknown token" do
      response = ApiClient.new.post("/api/v1/password_resets/not-a-real-token", user: {
        password:              "abcdef",
        password_confirmation: "abcdef",
      })

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "invalid_token"
    end

    it "rejects a password shorter than six characters but keeps the link usable" do
      user = UserFactory.create
      token = PasswordReset.issue(user)

      response = ApiClient.new.post("/api/v1/password_resets/#{token}", user: {
        password:              "abcde",
        password_confirmation: "abcde",
      })

      response.status_code.should eq 422
      details = JSON.parse(response.body)["error"]["details"]
      details["password"].as_a.map(&.as_s).should contain "must have at least 6 characters"
      UserQuery.new.id(user.id).first?.not_nil!.password_reset_token_hash.should_not be_nil
    end

    it "closes sessions opened with the old password" do
      user = UserFactory.create
      old_token = AuthHelper.token_for(user)
      reset_token = PasswordReset.issue(user)

      ApiClient.new.post("/api/v1/password_resets/#{reset_token}", user: {
        password:              "abcdef",
        password_confirmation: "abcdef",
      }).status_code.should eq 200

      ApiClient.new.with_cookie(old_token).get("/api/v1/me").status_code.should eq 401
    end
  end
end
