require "../spec_helper"

private def usage_headers(
  method : String,
  path : String,
  headers = HTTP::Headers.new,
) : HTTP::Headers
  request = HTTP::Request.new(method, path, headers)
  response = HTTP::Server::Response.new(IO::Memory.new)
  context = HTTP::Server::Context.new(request, response)

  handler = BuildUsageHandler.new
  handler.next = ->(_ctx : HTTP::Server::Context) { }
  handler.call(context)

  response.headers
end

private def create_file_build(project : Project, public_id : String) : Build
  path = File.tempname("build", ".zip")
  File.write(path, "bytes")

  begin
    SaveBuild.create!(
      project_id: project.id,
      public_id: public_id,
      kind: "file",
      size_bytes: 5_i64,
      stored_file: BuildStorage.store_file(path, "game.zip", public_id),
    )
  ensure
    File.delete?(path)
  end
end

private def build(id : Int64) : Build
  BuildQuery.new.id(id).first
end

describe BuildUsageHandler do
  it "counts a file download once and ignores resumed ranges and HEAD" do
    user = UserFactory.create
    project = ProjectFactory.create &.user_id(user.id)
    created = create_file_build(project, "file1")

    usage_headers("GET", "/media/build/file1/files/game.zip")
    build(created.id).downloads_count.should eq 1

    usage_headers("GET", "/media/build/file1/files/game.zip", HTTP::Headers{"Range" => "bytes=2-"})
    usage_headers("GET", "/media/build/file1/files/game.zip", HTTP::Headers{"Range" => "bytes=-3"})
    usage_headers("HEAD", "/media/build/file1/files/game.zip")
    usage_headers("GET", "/media/build/file1/other/game.zip")
    build(created.id).downloads_count.should eq 1

    build(created.id).stored_file.try(&.delete)
  end

  it "counts a browser build launch only for its entry page" do
    user = UserFactory.create
    project = ProjectFactory.create &.user_id(user.id)
    created = SaveBuild.create!(
      project_id: project.id,
      public_id: "web1",
      kind: "web",
      entry_path: "index.html",
      size_bytes: 1_i64,
    )

    headers = usage_headers("GET", "/media/web/web1/index.html")
    headers["Cache-Control"].should eq "no-cache"
    build(created.id).launches_count.should eq 1

    # Assets and other pages of the same build are part of the launch, not a
    # new one.
    usage_headers("GET", "/media/web/web1/assets/game.js")
    usage_headers("GET", "/media/web/web1/credits.html")
    build(created.id).launches_count.should eq 1

    # A repeated launch still counts: the entry page is revalidated each time.
    usage_headers("GET", "/media/web/web1/index.html")
    build(created.id).launches_count.should eq 2
  end

  it "does not count requests for other media" do
    user = UserFactory.create
    project = ProjectFactory.create &.user_id(user.id)
    created = create_file_build(project, "file2")

    usage_headers("GET", "/media/screenshot/1/image/file.jpg")
    usage_headers("GET", "/media/build/file2/files/game.zip")

    build(created.id).downloads_count.should eq 1
    build(created.id).stored_file.try(&.delete)
  end

  it "counts only builds that match the kind and the entry path" do
    user = UserFactory.create
    project = ProjectFactory.create &.user_id(user.id)
    file_build = create_file_build(project, "mixed")
    web_build = SaveBuild.create!(
      project_id: project.id,
      public_id: "mixedweb",
      kind: "web",
      entry_path: "start.html",
      size_bytes: 1_i64,
    )

    usage_headers("GET", "/media/build/mixed/files/other.zip")
    usage_headers("GET", "/media/build/mixed/files/game.zip")
    usage_headers("GET", "/media/web/mixedweb/start.html")
    usage_headers("GET", "/media/web/mixedweb/index.html")

    build(file_build.id).downloads_count.should eq 1
    build(web_build.id).launches_count.should eq 1

    build(file_build.id).stored_file.try(&.delete)
  end
end
