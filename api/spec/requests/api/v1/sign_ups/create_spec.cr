require "../../../../spec_helper"

describe Api::V1::SignUps::Create do
  it "creates an unconfirmed user, starts a session and sends the letter" do
    response = ApiClient.exec(Api::V1::SignUps::Create, user: {
      email:                 "new@example.com",
      username:              "new_user",
      display_name:          "New User",
      password:              "password1234",
      password_confirmation: "password1234",
    })

    response.status_code.should eq 201
    response.headers["Set-Cookie"].should contain "isho_auth="

    body = JSON.parse(response.body)
    body["email"].as_s.should eq "new@example.com"
    body["username"].as_s.should eq "new_user"
    body["email_confirmed"].as_bool.should be_false

    user = UserQuery.new.username("new_user").first?
    user.should_not be_nil
    user.not_nil!.email_confirmed?.should be_false

    Carbon::DevAdapter.delivered_emails.size.should eq 1
    Carbon::DevAdapter.delivered_emails.last.should be_a EmailConfirmationEmail
  end

  it "confirms the account with the token from the letter" do
    ApiClient.exec(Api::V1::SignUps::Create, user: {
      email:                 "confirm@example.com",
      username:              "confirm_user",
      password:              "password1234",
      password_confirmation: "password1234",
    })

    token = confirmation_token_from_last_email

    response = ApiClient.new.post("/api/v1/email_confirmations", token: token)

    response.status_code.should eq 200
    UserQuery.new.username("confirm_user").first?.not_nil!.email_confirmed?.should be_true
  end

  it "accepts a short password without digits or symbols" do
    response = ApiClient.exec(Api::V1::SignUps::Create, user: {
      email:                 "short@example.com",
      username:              "short_user",
      password:              "abcdef",
      password_confirmation: "abcdef",
    })

    response.status_code.should eq 201
    UserQuery.new.username("short_user").first?.should_not be_nil
  end

  it "rejects a password shorter than six characters" do
    response = ApiClient.exec(Api::V1::SignUps::Create, user: {
      email:                 "tiny@example.com",
      username:              "tiny_user",
      password:              "abcde",
      password_confirmation: "abcde",
    })

    response.status_code.should eq 422
    details = JSON.parse(response.body)["error"]["details"]
    details["password"].as_a.map(&.as_s).should contain "must have at least 6 characters"
    UserQuery.new.username("tiny_user").first?.should be_nil
  end

  it "rejects a mismatched password confirmation" do
    response = ApiClient.exec(Api::V1::SignUps::Create, user: {
      email:                 "bad@example.com",
      username:              "bad_user",
      password:              "password1234",
      password_confirmation: "password4321",
    })

    response.status_code.should eq 422
    JSON.parse(response.body)["error"]["code"].as_s.should eq "validation_failed"
    UserQuery.new.email("bad@example.com").first?.should be_nil
    Carbon::DevAdapter.delivered_emails.should be_empty
  end

  it "rejects a blacklisted email" do
    BlockEmail.create!(email: "blocked@example.com", username: "old_user")

    response = ApiClient.exec(Api::V1::SignUps::Create, user: {
      email:                 "Blocked@Example.com",
      username:              "new_user",
      password:              "password1234",
      password_confirmation: "password1234",
    })

    response.status_code.should eq 422
    details = JSON.parse(response.body)["error"]["details"]
    details["email"].as_a.map(&.as_s).should contain "is not allowed"
    UserQuery.new.email("blocked@example.com").first?.should be_nil
    Carbon::DevAdapter.delivered_emails.should be_empty
  end

  it "rejects a reserved username" do
    response = ApiClient.exec(Api::V1::SignUps::Create, user: {
      email:                 "admin@example.com",
      username:              "admin",
      password:              "password1234",
      password_confirmation: "password1234",
    })

    response.status_code.should eq 422
    details = JSON.parse(response.body)["error"]["details"]
    details["username"].as_a.map(&.as_s).should contain "is reserved"
  end
end
