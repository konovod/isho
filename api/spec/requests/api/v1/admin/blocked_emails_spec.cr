require "../../../../spec_helper"

describe Api::V1::Admin::BlockedEmails do
  describe "GET /api/v1/admin/blocked_emails" do
    it "lists blocked addresses with the last username for an admin" do
      admin = UserFactory.create &.is_admin(true)
      BlockEmail.create!(email: "gone@example.com", username: "gone_user")

      response = AuthHelper.client_for(admin).get("/api/v1/admin/blocked_emails")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      item = body["items"].as_a.find { |entry| entry["email"].as_s == "gone@example.com" }.not_nil!
      item["username"].as_s.should eq "gone_user"
      body["meta"]["total"].as_i64.should eq 1
    end

    it "searches by email or username" do
      admin = UserFactory.create &.is_admin(true)
      BlockEmail.create!(email: "first@example.com", username: "first_user")
      BlockEmail.create!(email: "second@example.com", username: "second_user")

      response = AuthHelper.client_for(admin).get("/api/v1/admin/blocked_emails?q=second")

      response.status_code.should eq 200
      items = JSON.parse(response.body)["items"].as_a
      items.size.should eq 1
      items.first["email"].as_s.should eq "second@example.com"
    end

    it "forbids regular users" do
      response = AuthHelper.client_for(UserFactory.create).get("/api/v1/admin/blocked_emails")

      response.status_code.should eq 403
    end
  end

  describe "DELETE /api/v1/admin/blocked_emails/:id" do
    it "removes the entry and lets the address register again" do
      admin = UserFactory.create &.is_admin(true)
      entry = BlockEmail.create!(email: "back@example.com", username: "back_user")

      response = AuthHelper.client_for(admin).delete("/api/v1/admin/blocked_emails/#{entry.id}")

      response.status_code.should eq 204
      BlockedEmailQuery.new.id(entry.id).first?.should be_nil

      sign_up = ApiClient.exec(Api::V1::SignUps::Create, user: {
        email:                 "back@example.com",
        username:              "back_again",
        password:              "password1234",
        password_confirmation: "password1234",
      })

      sign_up.status_code.should eq 201
    end

    it "returns 404 for a missing entry" do
      admin = UserFactory.create &.is_admin(true)

      response = AuthHelper.client_for(admin).delete("/api/v1/admin/blocked_emails/999999")

      response.status_code.should eq 404
    end

    it "forbids regular users" do
      entry = BlockEmail.create!(email: "keep@example.com")
      stranger = UserFactory.create

      response = AuthHelper.client_for(stranger).delete("/api/v1/admin/blocked_emails/#{entry.id}")

      response.status_code.should eq 403
      BlockedEmailQuery.new.id(entry.id).first?.should_not be_nil
    end
  end
end
