require "../../../../spec_helper"

describe "project tags" do
  describe "PATCH /api/v1/projects/:slug" do
    it "creates a tag from a free-form name" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)

      response = AuthHelper.client_for(owner).patch("/api/v1/projects/#{project.slug}", {
        project:   {title: project.title, kind: project.kind},
        tag_names: ["Космос"],
      })

      response.status_code.should eq 200

      tags = tags_for(project)
      tags.map(&.name).should eq ["Космос"]
      tags.first.slug.should eq "kosmos"
    end

    it "matches an existing tag by name even when its slug differs" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)
      Tag::SaveOperation.create!(name: "Экшен", slug: "action")

      response = AuthHelper.client_for(owner).patch("/api/v1/projects/#{project.slug}", {
        project:   {title: project.title, kind: project.kind},
        tag_names: ["Экшен"],
      })

      response.status_code.should eq 200
      TagQuery.new.results.size.should eq 1
      tags_for(project).map(&.slug).should eq ["action"]
    end

    it "reuses an existing tag instead of creating a duplicate" do
      owner = UserFactory.create
      first = ProjectFactory.create &.user_id(owner.id)
      second = ProjectFactory.create &.user_id(owner.id)
      client = AuthHelper.client_for(owner)

      client.patch("/api/v1/projects/#{first.slug}", {
        project:   {title: first.title, kind: first.kind},
        tag_names: ["Космос"],
      })
      client.patch("/api/v1/projects/#{second.slug}", {
        project:   {title: second.title, kind: second.kind},
        tag_names: ["космос"],
      })

      TagQuery.new.results.size.should eq 1
      tags_for(first).map(&.slug).should eq ["kosmos"]
      tags_for(second).map(&.slug).should eq ["kosmos"]
    end

    it "trims names and drops duplicates within one request" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)

      AuthHelper.client_for(owner).patch("/api/v1/projects/#{project.slug}", {
        project:   {title: project.title, kind: project.kind},
        tag_names: ["  Космос  ", "космос", "Космос"],
      })

      TagQuery.new.results.size.should eq 1
      tags_for(project).map(&.name).should eq ["Космос"]
    end

    it "does not attach the same tag twice when names share a slug" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)

      AuthHelper.client_for(owner).patch("/api/v1/projects/#{project.slug}", {
        project:   {title: project.title, kind: project.kind},
        tag_names: ["C++", "C"],
      })

      TagQuery.new.results.size.should eq 1
      tags_for(project).size.should eq 1
    end

    it "keeps at most eight tags" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)
      names = (1..10).map { |index| "тег #{index}" }

      AuthHelper.client_for(owner).patch("/api/v1/projects/#{project.slug}", {
        project:   {title: project.title, kind: project.kind},
        tag_names: names,
      })

      tags_for(project).size.should eq 8
    end

    it "skips blank and unslugifiable names" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)

      AuthHelper.client_for(owner).patch("/api/v1/projects/#{project.slug}", {
        project:   {title: project.title, kind: project.kind},
        tag_names: ["", "   ", "!!!"],
      })

      tags_for(project).should be_empty
      TagQuery.new.results.should be_empty
    end

    it "clears tags when given an empty array" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)
      client = AuthHelper.client_for(owner)
      client.patch("/api/v1/projects/#{project.slug}", {
        project:   {title: project.title, kind: project.kind},
        tag_names: ["Космос"],
      })

      client.patch("/api/v1/projects/#{project.slug}", {
        project:   {title: project.title, kind: project.kind},
        tag_names: [] of String,
      })

      tags_for(project).should be_empty
    end

    it "still accepts tag_slugs for backwards compatibility" do
      owner = UserFactory.create
      project = ProjectFactory.create &.user_id(owner.id)
      Tag::SaveOperation.create!(name: "RPG", slug: "rpg")

      AuthHelper.client_for(owner).patch("/api/v1/projects/#{project.slug}", {
        project:   {title: project.title, kind: project.kind},
        tag_slugs: ["rpg"],
      })

      tags_for(project).map(&.slug).should eq ["rpg"]
      TagQuery.new.results.size.should eq 1
    end
  end
end

private def tags_for(project : Project) : Array(Tag)
  ProjectQuery.new.id(project.id).preload_tags.first?.not_nil!.tags
end
