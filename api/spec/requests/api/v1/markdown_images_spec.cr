require "../../../spec_helper"
require "base64"

module MarkdownImageUploadHelper
  # 1x1 transparent PNG and a 1x1 GIF, enough for ImageMagick to process.
  PNG = Base64.decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lk3Y9AAAAABJRU5ErkJggg==")
  GIF = Base64.decode("R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==")

  def self.upload(
    client : ApiClient,
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
      .exec_raw(Api::V1::MarkdownImages::Create, body.to_s)
  end
end

describe Api::V1::MarkdownImages::Create do
  it "uploads an image and returns a URL for Markdown" do
    user = UserFactory.create

    response = MarkdownImageUploadHelper.upload(
      AuthHelper.client_for(user),
      MarkdownImageUploadHelper::PNG,
      "screenshot.png",
      "image/png",
    )

    response.status_code.should eq 201

    body = JSON.parse(response.body)
    id = body["id"].as_i64
    url = body["url"].as_s

    url.should contain("markdown_image/#{id}/image/")
    url.should end_with(".png")

    image = MarkdownImageQuery.new.id(id).first?
    image.should_not be_nil
    image.not_nil!.user_id.should eq user.id
    image.not_nil!.image.should_not be_nil
  end

  it "accepts GIF images" do
    user = UserFactory.create

    response = MarkdownImageUploadHelper.upload(
      AuthHelper.client_for(user),
      MarkdownImageUploadHelper::GIF,
      "animation.gif",
      "image/gif",
    )

    response.status_code.should eq 201
    JSON.parse(response.body)["url"].as_s.should end_with(".gif")
  end

  it "requires authentication" do
    response = ApiClient.new.post("/api/v1/markdown_images")

    response.status_code.should eq 401
  end

  it "rejects a request without a file" do
    user = UserFactory.create

    response = AuthHelper.client_for(user).post("/api/v1/markdown_images")

    response.status_code.should eq 422
    JSON.parse(response.body)["error"]["details"]["image_file"][0].as_s.should eq "is required"
  end

  it "rejects files that are not images" do
    user = UserFactory.create

    response = MarkdownImageUploadHelper.upload(
      AuthHelper.client_for(user),
      "not an image".to_slice,
      "notes.txt",
      "text/plain",
    )

    response.status_code.should eq 422
    JSON.parse(response.body)["error"]["code"].as_s.should eq "invalid_file_type"
    MarkdownImageQuery.new.select_count.should eq 0
  end

  it "blocks banned users" do
    admin = UserFactory.create &.is_admin(true)
    author = UserFactory.create
    BanUser.run!(user: author, moderator: admin, reason: "Спам", days: 2)

    response = MarkdownImageUploadHelper.upload(
      AuthHelper.client_for(author),
      MarkdownImageUploadHelper::PNG,
      "screenshot.png",
      "image/png",
    )

    response.status_code.should eq 403
    JSON.parse(response.body)["error"]["code"].as_s.should eq "user_banned"
  end
end
