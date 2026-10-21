require "../../../../spec_helper"

describe Api::V1::Me::Theme::Update do
  it "saves the chosen theme" do
    user = UserFactory.create

    response = AuthHelper.client_for(user).patch("/api/v1/me/theme", user: {theme: "light"})

    response.status_code.should eq 200
    JSON.parse(response.body)["theme"].as_s.should eq "light"
    UserQuery.new.id(user.id).first.not_nil!.theme.should eq "light"
  end

  it "rejects an unknown theme" do
    user = UserFactory.create

    response = AuthHelper.client_for(user).patch("/api/v1/me/theme", user: {theme: "sepia"})

    response.status_code.should eq 422
    JSON.parse(response.body)["error"]["code"].as_s.should eq "validation_failed"
    UserQuery.new.id(user.id).first.not_nil!.theme.should eq "dark"
  end

  it "requires a session" do
    response = ApiClient.new.patch("/api/v1/me/theme", user: {theme: "light"})

    response.status_code.should eq 401
  end
end
