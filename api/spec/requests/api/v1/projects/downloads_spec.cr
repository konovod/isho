require "../../../../spec_helper"

describe Api::V1::Projects::Downloads do
  it "creates an external download link" do
    user = UserFactory.create
    project = ProjectFactory.create &.user_id(user.id)

    response = AuthHelper.client_for(user).post("/api/v1/projects/#{project.slug}/downloads", download: {
      label:    "Windows build",
      url:      "https://drive.google.com/file/d/example/view",
      platform: "windows",
      version:  "1.0",
    })

    response.status_code.should eq 201
    JSON.parse(response.body)["url"].as_s.should eq "https://drive.google.com/file/d/example/view"
    DownloadQuery.new.project_id(project.id).select_count.should eq 1
  end

  it "defaults a blank label" do
    user = UserFactory.create
    project = ProjectFactory.create &.user_id(user.id)

    response = AuthHelper.client_for(user).post("/api/v1/projects/#{project.slug}/downloads", download: {
      label: "",
      url:   "https://example.com/build.zip",
    })

    response.status_code.should eq 201
    JSON.parse(response.body)["label"].as_s.should eq "Скачать"
  end

  it "rejects non-https links" do
    user = UserFactory.create
    project = ProjectFactory.create &.user_id(user.id)

    response = AuthHelper.client_for(user).post("/api/v1/projects/#{project.slug}/downloads", download: {
      label: "Unsafe build",
      url:   "http://example.com/build.zip",
    })

    response.status_code.should eq 422
    DownloadQuery.new.project_id(project.id).select_count.should eq 0
  end

  it "rejects local addresses" do
    user = UserFactory.create
    project = ProjectFactory.create &.user_id(user.id)

    response = AuthHelper.client_for(user).post("/api/v1/projects/#{project.slug}/downloads", download: {
      label: "Local build",
      url:   "https://127.0.0.1/build.zip",
    })

    response.status_code.should eq 422
  end
end
