require "../../../../spec_helper"

describe "GET /api/v1/tags" do
  it "orders tags by the number of published projects" do
    popular = Tag::SaveOperation.create!(name: "Popular", slug: "popular")
    rare = Tag::SaveOperation.create!(name: "Rare", slug: "rare")
    Tag::SaveOperation.create!(name: "Unused", slug: "unused")

    first = ProjectFactory.create &.status("published").published_at(Time.utc)
    second = ProjectFactory.create &.status("published").published_at(Time.utc)

    ProjectTag::SaveOperation.create!(project_id: first.id, tag_id: popular.id)
    ProjectTag::SaveOperation.create!(project_id: second.id, tag_id: popular.id)
    ProjectTag::SaveOperation.create!(project_id: first.id, tag_id: rare.id)

    response = ApiClient.new.get("/api/v1/tags")

    response.status_code.should eq 200
    items = JSON.parse(response.body)["items"].as_a
    items.map { |item| item["slug"].as_s }.should eq ["popular", "rare", "unused"]
    items.map { |item| item["projects_count"].as_i }.should eq [2, 1, 0]
  end

  it "does not count drafts" do
    tag = Tag::SaveOperation.create!(name: "Космос", slug: "kosmos")
    draft = ProjectFactory.create
    published = ProjectFactory.create &.status("published").published_at(Time.utc)

    ProjectTag::SaveOperation.create!(project_id: draft.id, tag_id: tag.id)
    ProjectTag::SaveOperation.create!(project_id: published.id, tag_id: tag.id)

    response = ApiClient.new.get("/api/v1/tags")

    item = JSON.parse(response.body)["items"].as_a.first
    item["projects_count"].as_i.should eq 1
  end

  it "searches by name and slug without regard to case" do
    Tag::SaveOperation.create!(name: "Космос", slug: "kosmos")
    Tag::SaveOperation.create!(name: "Хоррор", slug: "horror")

    by_name = JSON.parse(ApiClient.new.get("/api/v1/tags?q=КОСМ").body)["items"].as_a
    by_name.map { |item| item["slug"].as_s }.should eq ["kosmos"]

    by_slug = JSON.parse(ApiClient.new.get("/api/v1/tags?q=hor").body)["items"].as_a
    by_slug.map { |item| item["slug"].as_s }.should eq ["horror"]
  end

  it "limits the list but reports the total" do
    Tag::SaveOperation.create!(name: "First", slug: "first")
    Tag::SaveOperation.create!(name: "Second", slug: "second")
    Tag::SaveOperation.create!(name: "Third", slug: "third")

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
end
