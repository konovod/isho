require "../../../spec_helper"

describe Api::V1::EmailConfirmations do
  describe "POST /api/v1/email_confirmations" do
    it "confirms the address and drops the token" do
      user = UserFactory.create &.unconfirmed
      token = EmailConfirmation.issue(user)

      response = ApiClient.new.post("/api/v1/email_confirmations", token: token)

      response.status_code.should eq 200
      JSON.parse(response.body)["confirmed"].as_bool.should be_true

      confirmed = UserQuery.new.id(user.id).first?.not_nil!
      confirmed.email_confirmed?.should be_true
      confirmed.email_confirmation_token_hash.should be_nil
      confirmed.email_confirmation_sent_at.should be_nil
    end

    it "rejects an unknown token" do
      response = ApiClient.new.post("/api/v1/email_confirmations", token: "not-a-real-token")

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "invalid_token"
    end

    it "rejects an expired token" do
      user = UserFactory.create &.unconfirmed
      token = EmailConfirmation.issue(user)

      SaveEmailConfirmation.update!(
        user,
        email_confirmation_sent_at: (AppSettings::EMAIL_CONFIRMATION_TTL + 1.hour).ago,
      )

      response = ApiClient.new.post("/api/v1/email_confirmations", token: token)

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "invalid_token"
      UserQuery.new.id(user.id).first?.not_nil!.email_confirmed?.should be_false
    end

    it "accepts the link only once" do
      user = UserFactory.create &.unconfirmed
      token = EmailConfirmation.issue(user)

      ApiClient.new.post("/api/v1/email_confirmations", token: token).status_code.should eq 200
      ApiClient.new.post("/api/v1/email_confirmations", token: token).status_code.should eq 422
    end
  end

  describe "POST /api/v1/email_confirmations/resend" do
    it "sends a new letter and then reports the cooldown" do
      user = UserFactory.create &.unconfirmed
      client = AuthHelper.client_for(user)

      first = client.post("/api/v1/email_confirmations/resend")
      first.status_code.should eq 200
      JSON.parse(first.body)["sent"].as_bool.should be_true
      Carbon::DevAdapter.delivered_emails.size.should eq 1

      second = client.post("/api/v1/email_confirmations/resend")
      second.status_code.should eq 200
      body = JSON.parse(second.body)
      body["sent"].as_bool.should be_false
      body["retry_after"].as_i.should be > 0
      Carbon::DevAdapter.delivered_emails.size.should eq 1
    end

    it "does not send anything once the address is confirmed" do
      user = UserFactory.create

      response = AuthHelper.client_for(user).post("/api/v1/email_confirmations/resend")

      response.status_code.should eq 200
      JSON.parse(response.body)["already_confirmed"].as_bool.should be_true
      Carbon::DevAdapter.delivered_emails.should be_empty
    end

    it "requires a session" do
      ApiClient.new.post("/api/v1/email_confirmations/resend").status_code.should eq 401
    end
  end

  describe "gated actions" do
    it "does not publish a project before the address is confirmed" do
      user = UserFactory.create &.unconfirmed
      project = ProjectFactory.create &.user_id(user.id)

      response = AuthHelper.client_for(user).post("/api/v1/projects/#{project.slug}/publish")

      response.status_code.should eq 403
      JSON.parse(response.body)["error"]["code"].as_s.should eq "email_not_confirmed"
      ProjectQuery.new.id(project.id).first?.not_nil!.status.should eq "draft"
    end

    it "publishes after confirmation" do
      user = UserFactory.create &.unconfirmed
      project = ProjectFactory.create &.user_id(user.id)
      EmailConfirmation.confirm(EmailConfirmation.issue(user))

      response = AuthHelper.client_for(user).post("/api/v1/projects/#{project.slug}/publish")

      response.status_code.should eq 200
      ProjectQuery.new.id(project.id).first?.not_nil!.status.should eq "published"
    end

    it "does not let an unconfirmed user start a forum topic" do
      user = UserFactory.create &.unconfirmed
      ForumSectionFactory.create &.slug("site")

      response = AuthHelper.client_for(user).post("/api/v1/forum/sections/site/topics", forum_topic: {
        title: "Тема без подтверждения",
        body:  "Текст",
      })

      response.status_code.should eq 403
      JSON.parse(response.body)["error"]["code"].as_s.should eq "email_not_confirmed"
    end
  end
end
