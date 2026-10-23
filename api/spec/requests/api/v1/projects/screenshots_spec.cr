require "../../../../spec_helper"
require "base64"

module ScreenshotUploadHelper
  # 1x1 transparent PNG, enough for ImageMagick to process.
  PNG = Base64.decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lk3Y9AAAAABJRU5ErkJggg==")

  def self.upload(
    client : ApiClient,
    slug : String,
    bytes : Bytes,
    filename : String,
    content_type : String,
  ) : HTTP::Client::Response
    boundary = "----isho-spec-#{UUID.random}"
    body = IO::Memory.new
    body << "--#{boundary}\r\n"
    body << %(Content-Disposition: form-data; name="image_file"; filename="#{filename}"\r\n)
    body << "Content-Type: #{content_type}\r\n\r\n"
    body.write(bytes)
    body << "\r\n--#{boundary}--\r\n"

    client
      .headers("Content-Type": "multipart/form-data; boundary=#{boundary}")
      .exec_raw(Api::V1::Projects::Screenshots::Create.with(slug), body.to_s)
  end
end

private def screenshot_fixture(project : Project, position : Int32, is_cover : Bool) : Screenshot
  Screenshot::SaveOperation.create!(
    project_id: project.id,
    position: position,
    is_cover: is_cover,
  )
end

describe Api::V1::Projects::Screenshots::Update do
  it "moves the cover flag to the selected screenshot" do
    user = UserFactory.create
    project = ProjectFactory.create &.user_id(user.id)
    previous = screenshot_fixture(project, 0, is_cover: true)
    selected = screenshot_fixture(project, 1, is_cover: false)

    response = AuthHelper.client_for(user).patch(
      "/api/v1/projects/#{project.slug}/screenshots/#{selected.id}",
      screenshot: {is_cover: true},
    )

    response.status_code.should eq 200
    JSON.parse(response.body)["is_cover"].as_bool.should be_true

    ScreenshotQuery.new.id(previous.id).first?.not_nil!.is_cover.should be_false
    ScreenshotQuery.new.id(selected.id).first?.not_nil!.is_cover.should be_true
  end

  it "updates the caption and trims it" do
    user = UserFactory.create
    project = ProjectFactory.create &.user_id(user.id)
    screenshot = screenshot_fixture(project, 0, is_cover: true)

    response = AuthHelper.client_for(user).patch(
      "/api/v1/projects/#{project.slug}/screenshots/#{screenshot.id}",
      screenshot: {caption: "  Menu screen  "},
    )

    response.status_code.should eq 200
    JSON.parse(response.body)["caption"].as_s.should eq "Menu screen"
  end

  it "rejects a caption that is too long" do
    user = UserFactory.create
    project = ProjectFactory.create &.user_id(user.id)
    screenshot = screenshot_fixture(project, 0, is_cover: true)

    response = AuthHelper.client_for(user).patch(
      "/api/v1/projects/#{project.slug}/screenshots/#{screenshot.id}",
      screenshot: {caption: "x" * 201},
    )

    response.status_code.should eq 422
    JSON.parse(response.body)["error"]["code"].as_s.should eq "validation_failed"
  end
end

describe Api::V1::Projects::Screenshots::Create do
  it "stores a screenshot whose filename has no extension" do
    user = UserFactory.create
    project = ProjectFactory.create &.user_id(user.id)

    response = ScreenshotUploadHelper.upload(
      AuthHelper.client_for(user),
      project.slug,
      ScreenshotUploadHelper::PNG,
      "screenshot",
      "image/png",
    )

    response.status_code.should eq 201
    JSON.parse(response.body)["url"].as_s.should end_with(".png")
  end

  it "rejects a request without a file" do
    user = UserFactory.create
    project = ProjectFactory.create &.user_id(user.id)

    response = AuthHelper.client_for(user)
      .post("/api/v1/projects/#{project.slug}/screenshots")

    response.status_code.should eq 422
    JSON.parse(response.body)["error"]["details"]["image_file"][0].as_s.should eq "is required"
  end
end
