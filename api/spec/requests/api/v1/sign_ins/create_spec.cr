require "../../../../spec_helper"

describe Api::V1::SignIns::Create do
  it "signs in with valid credentials" do
    user = UserFactory.create

    response = ApiClient.exec(Api::V1::SignIns::Create, user: {
      email:    user.email,
      password: "password1234",
    })

    response.status_code.should eq 200
    response.headers["Set-Cookie"].should contain "isho_auth="
    JSON.parse(response.body)["username"].as_s.should eq user.username
  end

  it "rejects an incorrect password" do
    user = UserFactory.create

    response = ApiClient.exec(Api::V1::SignIns::Create, user: {
      email:    user.email,
      password: "not-the-password",
    })

    response.status_code.should eq 422
    JSON.parse(response.body)["error"]["code"].as_s.should eq "validation_failed"
  end
end
