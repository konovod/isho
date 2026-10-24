require "../../../spec_helper"

private def with_media_origin(value : String, &)
  previous = ENV["MEDIA_ORIGIN"]?
  ENV["MEDIA_ORIGIN"] = value
  begin
    yield
  ensure
    previous ? (ENV["MEDIA_ORIGIN"] = previous) : ENV.delete("MEDIA_ORIGIN")
  end
end

describe Internal::Tls::Allow do
  it "allows the host of an existing project" do
    project = ProjectFactory.create

    with_media_origin("https://games.example.test") do
      response = ApiClient.get("/internal/tls/allow?domain=#{project.slug}.games.example.test")

      response.status_code.should eq 200
    end
  end

  it "refuses a host no project owns" do
    with_media_origin("https://games.example.test") do
      response = ApiClient.get("/internal/tls/allow?domain=unknown.games.example.test")

      response.status_code.should eq 403
    end
  end

  it "refuses the app origin and nested hosts" do
    project = ProjectFactory.create

    with_media_origin("https://games.example.test") do
      ApiClient.get("/internal/tls/allow?domain=isho.example.test").status_code.should eq 403
      ApiClient.get("/internal/tls/allow?domain=a.#{project.slug}.games.example.test").status_code.should eq 403
      ApiClient.get("/internal/tls/allow?domain=games.example.test").status_code.should eq 403
    end
  end

  it "refuses everything without a media origin" do
    project = ProjectFactory.create

    response = ApiClient.get("/internal/tls/allow?domain=#{project.slug}.games.example.test")

    response.status_code.should eq 403
  end

  it "refuses a missing domain" do
    with_media_origin("https://games.example.test") do
      ApiClient.get("/internal/tls/allow").status_code.should eq 403
    end
  end
end
