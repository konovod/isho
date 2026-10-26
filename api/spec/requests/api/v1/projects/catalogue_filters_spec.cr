require "../../../../spec_helper"

describe "catalogue filters" do
  describe "GET /api/v1/projects" do
    it "keeps only projects carrying every selected tag" do
      unity = create_tag("Unity", "unity")
      two_d = create_tag("2D", "2d")
      both = publish_with_tags([unity, two_d])
      publish_with_tags([unity])
      publish_with_tags([two_d])

      project_slugs("/api/v1/projects?tags=unity,2d").should eq [both.slug]
    end

    it "filters by project type" do
      tool = publish(kind: "tool")
      publish(kind: "game")
      publish(kind: "asset")

      project_slugs("/api/v1/projects?kind=tool").should eq [tool.slug]
    end

    it "ignores an unknown type instead of failing" do
      publish(kind: "game")

      project_slugs("/api/v1/projects?kind=unknown").size.should eq 1
    end

    it "filters by development status" do
      beta = publish(dev_status: "beta")
      publish(dev_status: "active")
      publish(dev_status: "completed")

      project_slugs("/api/v1/projects?dev_status=beta").should eq [beta.slug]
    end

    it "ignores an unknown development status" do
      publish(dev_status: "beta")

      project_slugs("/api/v1/projects?dev_status=unknown").size.should eq 1
    end

    it "filters by genre" do
      horror = publish(genre: "horror")
      publish(genre: "puzzle")
      publish

      project_slugs("/api/v1/projects?genre=horror").should eq [horror.slug]
    end

    it "ignores an unknown genre" do
      publish(genre: "horror")

      project_slugs("/api/v1/projects?genre=unknown").size.should eq 1
    end

    it "combines type, development status and genre" do
      matching = publish(kind: "game", dev_status: "beta", genre: "horror")
      publish(kind: "game", dev_status: "beta", genre: "puzzle")
      publish(kind: "game", dev_status: "active", genre: "horror")
      publish(kind: "tool", dev_status: "beta")

      project_slugs("/api/v1/projects?kind=game&dev_status=beta&genre=horror").should eq [matching.slug]
    end

    it "keeps only projects with a browser build" do
      playable = publish
      add_web_build(playable)
      publish

      project_slugs("/api/v1/projects?web=1").should eq [playable.slug]
    end

    it "combines tags, type and browser builds" do
      unity = create_tag("Unity", "unity")
      matching = publish_with_tags([unity], kind: "tool")
      add_web_build(matching)
      publish_with_tags([unity], kind: "tool")
      publish_with_tags([unity], kind: "game")
      publish_with_tags([] of Tag, kind: "tool")

      project_slugs("/api/v1/projects?tags=unity&kind=tool&web=1").should eq [matching.slug]
    end

    it "still accepts the old single tag parameter" do
      unity = create_tag("Unity", "unity")
      matching = publish_with_tags([unity])
      publish_with_tags([] of Tag)

      project_slugs("/api/v1/projects?tag=unity").should eq [matching.slug]
    end

    it "returns nothing for a tag that does not exist" do
      publish_with_tags([] of Tag)

      project_slugs("/api/v1/projects?tags=missing").should be_empty
    end

    it "does not count drafts" do
      unity = create_tag("Unity", "unity")
      ProjectTag::SaveOperation.create!(
        project_id: ProjectFactory.create.id,
        tag_id: unity.id,
      )

      project_slugs("/api/v1/projects?tags=unity").should be_empty
    end
  end

  describe "GET /api/v1/tags" do
    it "leaves only tags compatible with the selection" do
      unity = create_tag("Unity", "unity")
      two_d = create_tag("2D", "2d")
      music = create_tag("Музыка", "muzyka")
      2.times { publish_with_tags([unity, two_d]) }
      publish_with_tags([unity, music])

      # The selected tag always comes first; a tag that occurs once is below
      # the default threshold.
      tag_slugs("/api/v1/tags?tags=unity").should eq ["unity", "2d"]
      tag_slugs("/api/v1/tags?tags=unity&min_projects=1").should eq ["unity", "2d", "muzyka"]
    end

    it "counts only projects that match the whole filter" do
      unity = create_tag("Unity", "unity")
      two_d = create_tag("2D", "2d")
      publish_with_tags([unity, two_d], kind: "tool")
      publish_with_tags([unity, two_d], kind: "game")

      items = tag_items("/api/v1/tags?tags=unity&kind=tool&min_projects=1")
      items["items"].as_a.map(&.["slug"].as_s).should eq ["unity", "2d"]
      items["items"].as_a.map(&.["projects_count"].as_i).should eq [1, 1]
    end

    it "counts only projects with the selected development status and genre" do
      unity = create_tag("Unity", "unity")
      publish_with_tags([unity], dev_status: "beta", genre: "horror")
      publish_with_tags([unity], dev_status: "active", genre: "horror")

      items = tag_items("/api/v1/tags?dev_status=beta&genre=horror&min_projects=1")
      items["items"].as_a.map(&.["projects_count"].as_i).should eq [1]
    end

    it "keeps a selected tag when the tag search would hide it" do
      unity = create_tag("Unity", "unity")
      two_d = create_tag("2D", "2d")
      2.times { publish_with_tags([unity, two_d]) }

      tag_slugs("/api/v1/tags?tags=unity&q=2d").should eq ["unity", "2d"]
    end

    it "keeps selected tags when the combination has no projects" do
      unity = create_tag("Unity", "unity")
      publish_with_tags([unity])
      music = create_tag("Музыка", "muzyka")
      publish_with_tags([music])

      items = tag_items("/api/v1/tags?tags=unity,muzyka&min_projects=1")
      items["items"].as_a.map(&.["slug"].as_s).should eq ["unity", "muzyka"]
      items["items"].as_a.map(&.["projects_count"].as_i).should eq [0, 0]
    end

    it "hides an adult-only tag from visitors even when it is selected" do
      adult = create_tag("Adult", "adult")
      2.times { publish_with_tags([adult], nsfw: true) }

      tag_slugs("/api/v1/tags?tags=adult").should be_empty
    end

    it "reports the total of compatible tags" do
      3.times do |index|
        tag = create_tag("Tag #{index}", "tag-#{index}")
        2.times { publish_with_tags([tag]) }
      end

      body = tag_items("/api/v1/tags?limit=1")
      body["items"].as_a.size.should eq 1
      body["meta"]["total"].as_i.should eq 3
    end
  end
end

private def create_tag(name : String, slug : String) : Tag
  Tag::SaveOperation.create!(name: name, slug: slug)
end

private def publish(kind = "game", nsfw = false, dev_status = "active", genre : String? = nil) : Project
  ProjectFactory.create do |operation|
    operation.status("published")
    operation.published_at(Time.utc)
    operation.kind(kind)
    operation.nsfw(nsfw)
    operation.dev_status(dev_status)
    operation.genre(genre) if genre
    operation
  end
end

private def publish_with_tags(
  tags : Array(Tag),
  kind = "game",
  nsfw = false,
  dev_status = "active",
  genre : String? = nil,
) : Project
  project = publish(kind: kind, nsfw: nsfw, dev_status: dev_status, genre: genre)
  tags.each { |tag| ProjectTag::SaveOperation.create!(project_id: project.id, tag_id: tag.id) }
  project
end

private def add_web_build(project : Project) : Build
  SaveBuild.create!(
    project_id: project.id,
    public_id: UUID.random.to_s,
    kind: "web",
    entry_path: "index.html",
    size_bytes: 1_i64,
  )
end

private def project_slugs(path : String) : Array(String)
  response = ApiClient.new.get(path)
  response.status_code.should eq 200
  JSON.parse(response.body)["items"].as_a.map(&.["slug"].as_s)
end

private def tag_slugs(path : String) : Array(String)
  tag_items(path)["items"].as_a.map(&.["slug"].as_s)
end

private def tag_items(path : String) : JSON::Any
  response = ApiClient.new.get(path)
  response.status_code.should eq 200
  JSON.parse(response.body)
end
