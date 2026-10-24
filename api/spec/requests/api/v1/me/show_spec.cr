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

  it "ignores a plain cookie when the secure one is expected" do
    user = UserFactory.create
    token = AuthHelper.token_for(user)

    with_cookie_secure("true") do
      # A sibling host can set `isho_auth` for the parent domain; only the
      # host-bound `__Host-` name counts once cookies are Secure.
      response = ApiClient.new.headers("Cookie": "isho_auth=#{token}").exec(Api::V1::Me::Show)

      response.status_code.should eq 401
    end
  end
end

private def with_cookie_secure(value : String, &)
  previous = ENV["COOKIE_SECURE"]?
  ENV["COOKIE_SECURE"] = value
  begin
    yield
  ensure
    previous ? (ENV["COOKIE_SECURE"] = previous) : ENV.delete("COOKIE_SECURE")
  end
end
