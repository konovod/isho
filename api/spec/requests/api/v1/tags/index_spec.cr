require "../../../../spec_helper"

describe "GET /api/v1/tags" do
  it "shows only tags used by more than one visible project" do
    popular = Tag::SaveOperation.create!(name: "Popular", slug: "popular")
    rare = Tag::SaveOperation.create!(name: "Rare", slug: "rare")
    Tag::SaveOperation.create!(name: "Unused", slug: "unused")

    publish_with_tag(popular)
    publish_with_tag(popular)
    publish_with_tag(rare)

    response = ApiClient.new.get("/api/v1/tags")

    response.status_code.should eq 200
    body = JSON.parse(response.body)
    items = body["items"].as_a
    items.map { |item| item["slug"].as_s }.should eq ["popular"]
    items.map { |item| item["projects_count"].as_i }.should eq [2]
    body["meta"]["total"].as_i.should eq 1
  end

  it "does not count drafts" do
    tag = Tag::SaveOperation.create!(name: "Космос", slug: "kosmos")
    publish_with_tag(tag)
    publish_with_tag(tag)
    ProjectTag::SaveOperation.create!(project_id: ProjectFactory.create.id, tag_id: tag.id)

    response = ApiClient.new.get("/api/v1/tags")

    item = JSON.parse(response.body)["items"].as_a.first
    item["projects_count"].as_i.should eq 2
  end

  it "searches by name and slug without regard to case" do
    kosmos = Tag::SaveOperation.create!(name: "Космос", slug: "kosmos")
    horror = Tag::SaveOperation.create!(name: "Хоррор", slug: "horror")
    2.times { publish_with_tag(kosmos) }
    2.times { publish_with_tag(horror) }

    by_name = JSON.parse(ApiClient.new.get("/api/v1/tags?q=КОСМ").body)["items"].as_a
    by_name.map { |item| item["slug"].as_s }.should eq ["kosmos"]

    by_slug = JSON.parse(ApiClient.new.get("/api/v1/tags?q=hor").body)["items"].as_a
    by_slug.map { |item| item["slug"].as_s }.should eq ["horror"]
  end

  it "limits the list but reports the total" do
    first = Tag::SaveOperation.create!(name: "First", slug: "first")
    second = Tag::SaveOperation.create!(name: "Second", slug: "second")
    third = Tag::SaveOperation.create!(name: "Third", slug: "third")
    2.times { publish_with_tag(first) }
    2.times { publish_with_tag(second) }
    2.times { publish_with_tag(third) }

    response = ApiClient.new.get("/api/v1/tags?limit=2")
    body = JSON.parse(response.body)

    body["items"].as_a.size.should eq 2
    body["meta"]["total"].as_i.should eq 3
  end

  it "returns an empty list when nothing matches" do
    Tag::SaveOperation.create!(name: "Космос", slug: "kosmos")

    response = ApiClient.new.get("/api/v1/tags?q=нет-такого")

    JSON.parse(response.body)["items"].as_a.should be_empty
  end

  it "hides adult tags from visitors" do
    tag = Tag::SaveOperation.create!(name: "Adult", slug: "adult")
    2.times { publish_with_tag(tag, true) }

    ["/api/v1/tags", "/api/v1/tags?min_projects=1"].each do |path|
      JSON.parse(ApiClient.new.get(path).body)["items"].as_a.should be_empty
    end

    member = UserFactory.create
    member_items = JSON.parse(AuthHelper.client_for(member).get("/api/v1/tags").body)["items"].as_a
    member_items.map { |item| item["slug"].as_s }.should eq ["adult"]

    admin = UserFactory.create &.is_admin(true).show_nsfw(false)
    admin_items = JSON.parse(AuthHelper.client_for(admin).get("/api/v1/tags").body)["items"].as_a
    admin_items.map { |item| item["slug"].as_s }.should eq ["adult"]
  end

  it "includes a single-project tag when the minimum is lowered" do
    rare = Tag::SaveOperation.create!(name: "Rare", slug: "rare")
    publish_with_tag(rare)

    response = ApiClient.new.get("/api/v1/tags?min_projects=1")

    items = JSON.parse(response.body)["items"].as_a
    items.map { |item| item["slug"].as_s }.should eq ["rare"]
  end
end

private def publish_with_tag(tag : Tag, nsfw = false) : Project
  project = ProjectFactory.create &.status("published").published_at(Time.utc).nsfw(nsfw)
  ProjectTag::SaveOperation.create!(project_id: project.id, tag_id: tag.id)
  project
end
