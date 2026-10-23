require "../../../../spec_helper"

describe Api::V1::Me::Preferences::Update do
  it "saves content preferences" do
    user = UserFactory.create

    response = AuthHelper.client_for(user).patch("/api/v1/me/preferences", user: {
      show_nsfw:    false,
      max_ai_usage: "partial",
    })

    response.status_code.should eq 200
    body = JSON.parse(response.body)
    body["show_nsfw"].as_bool.should be_false
    body["max_ai_usage"].as_s.should eq "partial"

    saved = UserQuery.new.id(user.id).first.not_nil!
    saved.show_nsfw.should be_false
    saved.max_ai_usage.should eq "partial"
  end

  it "keeps the other preference when only one is sent" do
    user = UserFactory.create &.show_nsfw(false).max_ai_usage("partial")

    response = AuthHelper.client_for(user).patch("/api/v1/me/preferences", user: {
      show_nsfw: true,
    })

    response.status_code.should eq 200
    saved = UserQuery.new.id(user.id).first.not_nil!
    saved.show_nsfw.should be_true
    saved.max_ai_usage.should eq "partial"
  end

  it "rejects an unknown AI usage level" do
    user = UserFactory.create

    response = AuthHelper.client_for(user).patch("/api/v1/me/preferences", user: {
      max_ai_usage: "assisted",
    })

    response.status_code.should eq 422
    JSON.parse(response.body)["error"]["details"]["max_ai_usage"].as_a.should_not be_empty
    UserQuery.new.id(user.id).first.not_nil!.max_ai_usage.should eq "full"
  end

  it "requires a session" do
    response = ApiClient.new.patch("/api/v1/me/preferences", user: {
      show_nsfw: false,
    })

    response.status_code.should eq 401
  end
end
