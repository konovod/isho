require "../../../../spec_helper"

describe Api::V1::SignUps::Create do
  it "creates a user and starts a session" do
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
    UserQuery.new.username("new_user").first?.should_not be_nil
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
