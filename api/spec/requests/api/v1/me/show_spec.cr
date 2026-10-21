require "../../../../spec_helper"

describe Api::V1::Me::Show do
  it "returns the signed in user" do
    user = UserFactory.create

    response = AuthHelper.client_for(user).exec(Api::V1::Me::Show)

    response.status_code.should eq 200
    body = JSON.parse(response.body)
    body["username"].as_s.should eq user.username
    body["email"].as_s.should eq user.email
  end

  it "returns 401 without a session" do
    response = ApiClient.exec(Api::V1::Me::Show)

    response.status_code.should eq 401
    JSON.parse(response.body)["error"]["code"].as_s.should eq "unauthorized"
  end
end
