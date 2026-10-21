require "../../../../spec_helper"

describe Api::V1::SignIns::Create do
  it "signs in with an email" do
    user = UserFactory.create

    response = ApiClient.exec(Api::V1::SignIns::Create, user: {
      login:    user.email,
      password: "password1234",
    })

    response.status_code.should eq 200
    response.headers["Set-Cookie"].should contain "isho_auth="
    JSON.parse(response.body)["username"].as_s.should eq user.username
  end

  it "signs in with a username regardless of case" do
    user = UserFactory.create

    response = ApiClient.exec(Api::V1::SignIns::Create, user: {
      login:    user.username.upcase,
      password: "password1234",
    })

    response.status_code.should eq 200
    JSON.parse(response.body)["username"].as_s.should eq user.username
  end

  it "still accepts user[email] from older clients" do
    user = UserFactory.create

    response = ApiClient.exec(Api::V1::SignIns::Create, user: {
      email:    user.email,
      password: "password1234",
    })

    response.status_code.should eq 200
  end

  it "rejects an incorrect password" do
    user = UserFactory.create

    response = ApiClient.exec(Api::V1::SignIns::Create, user: {
      login:    user.username,
      password: "not-the-password",
    })

    response.status_code.should eq 422
    JSON.parse(response.body)["error"]["code"].as_s.should eq "validation_failed"
  end

  it "does not reveal whether the login exists" do
    user = UserFactory.create

    wrong_password = ApiClient.exec(Api::V1::SignIns::Create, user: {
      login:    user.username,
      password: "not-the-password",
    })
    unknown_login = ApiClient.exec(Api::V1::SignIns::Create, user: {
      login:    "nobody_here",
      password: "password1234",
    })

    wrong_password.status_code.should eq 422
    unknown_login.status_code.should eq 422
    wrong_password.body.should eq unknown_login.body
  end
end
