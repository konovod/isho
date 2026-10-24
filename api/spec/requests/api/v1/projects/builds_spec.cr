require "../../../../spec_helper"
require "compress/zip"

module BuildUploadHelper
  def self.start(
    client : ApiClient,
    slug : String,
    kind : String,
    filename : String,
    total_bytes : Int32 | Int64,
  ) : HTTP::Client::Response
    client.post("/api/v1/projects/#{slug}/uploads", upload: {
      kind:        kind,
      filename:    filename,
      total_bytes: total_bytes,
    })
  end

  def self.put_chunk(
    client : ApiClient,
    slug : String,
    token : String,
    index : Int32,
    body : String,
  ) : HTTP::Client::Response
    client
      .exec_raw(Api::V1::Projects::Uploads::Chunk.with(slug, token, index.to_s), body)
  end

  def self.finish(
    client : ApiClient,
    slug : String,
    token : String,
    build = {} of String => String,
  ) : HTTP::Client::Response
    client.post("/api/v1/projects/#{slug}/uploads/#{token}/finish", build: build)
  end

  # One small chunk is enough for most cases: the chunk size is 8 MB and the
  # fixtures are a few bytes.
  def self.upload(
    client : ApiClient,
    slug : String,
    filename : String,
    contents : String,
    kind : String = "file",
    build = {} of String => String,
  ) : HTTP::Client::Response
    started = start(client, slug, kind, filename, contents.bytesize)
    started.status_code.should eq 201
    token = JSON.parse(started.body)["token"].as_s

    chunked = put_chunk(client, slug, token, 0, contents)
    chunked.status_code.should eq 200

    finish(client, slug, token, build)
  end

  def self.zip(path : String, entries : Hash(String, String)) : Nil
    Compress::Zip::Writer.open(path) do |zip|
      entries.each { |name, body| zip.add(name, body) }
    end
  end
end

describe Api::V1::Projects::Uploads do
  describe "a downloadable build" do
    it "stores the chunks and creates a build" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)
      contents = "fake executable bytes"

      response = BuildUploadHelper.upload(
        AuthHelper.client_for(user),
        project.slug,
        "game.zip",
        contents,
        build: {"label" => "Windows build", "platform" => "windows", "version" => "1.0"},
      )

      response.status_code.should eq 201
      body = JSON.parse(response.body)
      body["kind"].as_s.should eq "file"
      body["label"].as_s.should eq "Windows build"
      body["size_bytes"].as_i64.should eq contents.bytesize
      body["url"].as_s.should contain("/files/")
      body["url"].as_s.should end_with("game.zip")

      UploadSessionQuery.new.select_count.should eq 0

      build = BuildQuery.new.project_id(project.id).first?
      build.should_not be_nil
      build.not_nil!.stored_file.should_not be_nil
      build.not_nil!.stored_file.not_nil!.exists?.should be_true

      build.not_nil!.stored_file.not_nil!.delete
    end

    it "returns builds with the project" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)

      BuildUploadHelper.upload(
        AuthHelper.client_for(user),
        project.slug,
        "game.zip",
        "bytes",
      )

      response = AuthHelper.client_for(user).get("/api/v1/projects/#{project.slug}")
      builds = JSON.parse(response.body)["builds"].as_a
      builds.size.should eq 1
      builds.first["kind"].as_s.should eq "file"

      BuildQuery.new.project_id(project.id).results.each do |build|
        build.stored_file.try(&.delete)
      end
    end

    it "deletes the file together with the build" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)

      created = BuildUploadHelper.upload(
        AuthHelper.client_for(user),
        project.slug,
        "game.zip",
        "bytes",
      )
      build = BuildQuery.new.id(JSON.parse(created.body)["id"].as_i64).first.not_nil!
      stored = build.stored_file.not_nil!

      response = AuthHelper.client_for(user).delete("/api/v1/projects/#{project.slug}/builds/#{build.id}")

      response.status_code.should eq 204
      BuildQuery.new.select_count.should eq 0
      stored.exists?.should be_false
    end
  end

  describe "chunks" do
    it "resumes the same upload instead of starting another" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)
      client = AuthHelper.client_for(user)

      first = BuildUploadHelper.start(client, project.slug, "file", "game.zip", 10)
      first.status_code.should eq 201
      token = JSON.parse(first.body)["token"].as_s

      second = BuildUploadHelper.start(client, project.slug, "file", "game.zip", 10)

      second.status_code.should eq 200
      JSON.parse(second.body)["token"].as_s.should eq token
      UploadSessionQuery.new.select_count.should eq 1
    end

    it "accepts a repeated chunk without appending it twice" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)
      client = AuthHelper.client_for(user)

      started = BuildUploadHelper.start(client, project.slug, "file", "game.zip", 5)
      token = JSON.parse(started.body)["token"].as_s

      first = BuildUploadHelper.put_chunk(client, project.slug, token, 0, "hello")
      first.status_code.should eq 200

      second = BuildUploadHelper.put_chunk(client, project.slug, token, 0, "hello")
      second.status_code.should eq 200
      JSON.parse(second.body)["received_bytes"].as_i64.should eq 5

      finished = BuildUploadHelper.finish(client, project.slug, token)
      finished.status_code.should eq 201

      BuildQuery.new.project_id(project.id).results.each do |build|
        build.stored_file.try(&.delete)
      end
    end

    it "rejects an out-of-order chunk" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)
      client = AuthHelper.client_for(user)

      started = BuildUploadHelper.start(client, project.slug, "file", "game.zip", 5)
      token = JSON.parse(started.body)["token"].as_s

      response = BuildUploadHelper.put_chunk(client, project.slug, token, 3, "hello")

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "invalid_chunk"
      UploadSessionQuery.new.select_count.should eq 1
    end

    it "refuses to finish an incomplete upload" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)
      client = AuthHelper.client_for(user)

      started = BuildUploadHelper.start(client, project.slug, "file", "game.zip", 10)
      token = JSON.parse(started.body)["token"].as_s

      response = BuildUploadHelper.finish(client, project.slug, token)

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "upload_incomplete"
    end
  end

  describe "quotas" do
    it "rejects an upload that does not fit in the project limit" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)

      with_env("STORAGE_PROJECT_LIMIT_BYTES", "5") do
        response = BuildUploadHelper.start(AuthHelper.client_for(user), project.slug, "file", "big.zip", 10)
        response.status_code.should eq 422
        JSON.parse(response.body)["error"]["code"].as_s.should eq "project_storage_quota_exceeded"
      end

      UploadSessionQuery.new.select_count.should eq 0
    end

    it "rejects an upload that does not fit in the account limit" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)

      with_env("STORAGE_ACCOUNT_LIMIT_BYTES", "5") do
        response = BuildUploadHelper.start(AuthHelper.client_for(user), project.slug, "file", "big.zip", 10)
        response.status_code.should eq 422
        JSON.parse(response.body)["error"]["code"].as_s.should eq "storage_quota_exceeded"
      end
    end

    it "counts unpacked browser builds against the project limit" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)
      client = AuthHelper.client_for(user)
      zip_path = File.tempname("build", ".zip")
      BuildUploadHelper.zip(zip_path, {"index.html" => "<html>" + ("x" * 10_000) + "</html>"})

      begin
        contents = File.read(zip_path)
        # The zip itself fits, the unpacked page does not.
        limit = contents.bytesize + 100

        with_env("STORAGE_PROJECT_LIMIT_BYTES", limit.to_s) do
          started = BuildUploadHelper.start(client, project.slug, "web", "game.zip", contents.bytesize)
          started.status_code.should eq 201
          token = JSON.parse(started.body)["token"].as_s

          BuildUploadHelper.put_chunk(client, project.slug, token, 0, contents).status_code.should eq 200

          response = BuildUploadHelper.finish(client, project.slug, token)
          response.status_code.should eq 422
          JSON.parse(response.body)["error"]["code"].as_s.should eq "project_storage_quota_exceeded"
        end
        BuildQuery.new.select_count.should eq 0
      ensure
        File.delete?(zip_path)
      end
    end
  end

  describe "a browser build" do
    it "unpacks the archive and returns a playable URL" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)
      zip_path = File.tempname("build", ".zip")
      BuildUploadHelper.zip(zip_path, {
        "index.html"       => "<html><body>hi</body></html>",
        "assets/game.js"   => "console.log('hi')",
        "assets/style.css" => "body { margin: 0 }",
      })

      begin
        response = BuildUploadHelper.upload(
          AuthHelper.client_for(user), project.slug, "game.zip", File.read(zip_path), "web",
        )

        puts "WEB RESPONSE: #{response.status_code} #{response.body}" unless response.status_code == 201
        response.status_code.should eq 201
        body = JSON.parse(response.body)
        body["kind"].as_s.should eq "web"
        body["entry_path"].as_s.should eq "index.html"
        body["play_url"].as_s.should start_with("/media/web/")
        body["play_url"].as_s.should end_with("/index.html")

        build = BuildQuery.new.id(body["id"].as_i64).first.not_nil!
        directory = BuildStorage.web_dir(build.public_id)
        File.exists?(File.join(directory, "index.html")).should be_true
        File.exists?(File.join(directory, "assets", "game.js")).should be_true

        UploadSessionQuery.new.select_count.should eq 0

        BuildStorage.remove_web_dir(build.public_id)
      ensure
        File.delete?(zip_path)
      end
    end

    it "points play URLs at the media origin when one is configured" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)
      zip_path = File.tempname("build", ".zip")
      BuildUploadHelper.zip(zip_path, {"index.html" => "<html><body>hi</body></html>"})

      begin
        with_env("MEDIA_ORIGIN", "https://games.example.test/") do
          response = BuildUploadHelper.upload(
            AuthHelper.client_for(user), project.slug, "game.zip", File.read(zip_path), "web",
          )

          response.status_code.should eq 201
          body = JSON.parse(response.body)
          body["play_url"].as_s.should start_with("https://games.example.test/media/web/")
          body["play_url"].as_s.should end_with("/index.html")

          build = BuildQuery.new.id(body["id"].as_i64).first.not_nil!
          BuildStorage.remove_web_dir(build.public_id)
        end
      ensure
        File.delete?(zip_path)
      end
    end

    it "rejects path traversal in the archive" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)
      zip_path = File.tempname("build", ".zip")
      BuildUploadHelper.zip(zip_path, {"index.html" => "<html></html>", "../evil.txt" => "nope"})

      begin
        response = BuildUploadHelper.upload(
          AuthHelper.client_for(user), project.slug, "game.zip", File.read(zip_path), "web",
        )

        response.status_code.should eq 422
        JSON.parse(response.body)["error"]["code"].as_s.should eq "invalid_archive"
        BuildQuery.new.select_count.should eq 0
      ensure
        File.delete?(zip_path)
      end
    end

    it "requires an index.html" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)
      zip_path = File.tempname("build", ".zip")
      BuildUploadHelper.zip(zip_path, {"game.js" => "console.log('hi')"})

      begin
        response = BuildUploadHelper.upload(
          AuthHelper.client_for(user), project.slug, "game.zip", File.read(zip_path), "web",
        )

        response.status_code.should eq 422
        JSON.parse(response.body)["error"]["code"].as_s.should eq "index_html_missing"
      ensure
        File.delete?(zip_path)
      end
    end
  end

  describe "storage" do
    it "reports used space and the limits" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)
      BuildUploadHelper.upload(AuthHelper.client_for(user), project.slug, "game.zip", "1234567890")

      response = AuthHelper.client_for(user).get("/api/v1/me/storage")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["used_bytes"].as_i64.should eq 10
      body["limit_bytes"].as_i64.should eq AppSettings.account_storage_limit
      body["projects"].as_a.first["slug"].as_s.should eq project.slug

      BuildQuery.new.project_id(project.id).results.each do |build|
        build.stored_file.try(&.delete)
      end
    end

    it "requires a session" do
      ApiClient.new.get("/api/v1/me/storage").status_code.should eq 401
    end
  end

  describe "access" do
    it "returns 404 for someone else's project" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)
      stranger = UserFactory.create

      response = BuildUploadHelper.start(AuthHelper.client_for(stranger), project.slug, "file", "x.zip", 1)

      response.status_code.should eq 404
    end

    it "requires a confirmed email" do
      user = UserFactory.create &.unconfirmed
      project = ProjectFactory.create &.user_id(user.id)

      response = BuildUploadHelper.start(AuthHelper.client_for(user), project.slug, "file", "x.zip", 1)

      response.status_code.should eq 403
      JSON.parse(response.body)["error"]["code"].as_s.should eq "email_not_confirmed"
    end

    it "stops a project with too many builds" do
      user = UserFactory.create
      project = ProjectFactory.create &.user_id(user.id)

      AppSettings::MAX_BUILDS.times do
        SaveBuild.create!(
          project_id: project.id,
          public_id: UUID.random.to_s,
          kind: "web",
          entry_path: "index.html",
          size_bytes: 1_i64,
        )
      end

      response = BuildUploadHelper.start(AuthHelper.client_for(user), project.slug, "file", "x.zip", 1)

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "build_limit_reached"
    end
  end
end

private def with_env(key : String, value : String, &)
  previous = ENV[key]?
  ENV[key] = value
  begin
    yield
  ensure
    previous ? (ENV[key] = previous) : ENV.delete(key)
  end
end
