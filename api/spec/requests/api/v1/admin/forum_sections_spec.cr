require "../../../../spec_helper"

describe Api::V1::Admin::Forum::Sections do
  describe "GET /api/v1/admin/forum/sections" do
    it "lists sections in display order for an admin" do
      admin = UserFactory.create &.is_admin(true)
      ForumSectionFactory.create &.slug("second").position(20)
      ForumSectionFactory.create &.slug("first").position(10)

      response = AuthHelper.client_for(admin).get("/api/v1/admin/forum/sections")

      response.status_code.should eq 200
      items = JSON.parse(response.body)["items"].as_a
      items.map(&.["slug"].as_s).should eq ["first", "second"]
    end

    it "counts every topic and post, including drafts in the projects section" do
      admin = UserFactory.create &.is_admin(true)
      section = ForumSectionFactory.create &.slug("projects")
      project = ProjectFactory.create
      ForumTopicFactory.create &.section_id(section.id).project_id(project.id).replies_count(2)

      response = AuthHelper.client_for(admin).get("/api/v1/admin/forum/sections")

      item = JSON.parse(response.body)["items"].as_a.first
      item["topics_count"].as_i64.should eq 1
      item["posts_count"].as_i64.should eq 3
    end

    it "forbids regular users" do
      response = AuthHelper.client_for(UserFactory.create).get("/api/v1/admin/forum/sections")

      response.status_code.should eq 403
    end
  end

  describe "POST /api/v1/admin/forum/sections" do
    it "creates a section and builds its slug from the title" do
      admin = UserFactory.create &.is_admin(true)

      response = AuthHelper.client_for(admin).post("/api/v1/admin/forum/sections", forum_section: {
        title:       "Джемы и конкурсы",
        description: "Игровые джемы и конкурсы.",
        group_title: "Сообщество",
      })

      response.status_code.should eq 201
      body = JSON.parse(response.body)
      body["slug"].as_s.should eq "dzhemy-i-konkursy"
      body["position"].as_i64.should be > 0
      body["topics_count"].as_i64.should eq 0
    end

    it "normalizes a custom slug" do
      admin = UserFactory.create &.is_admin(true)

      response = AuthHelper.client_for(admin).post("/api/v1/admin/forum/sections", forum_section: {
        title: "Джемы",
        slug:  "Jams & Contests",
      })

      response.status_code.should eq 201
      JSON.parse(response.body)["slug"].as_s.should eq "jams-contests"
    end

    it "appends a new section after the last one by default" do
      admin = UserFactory.create &.is_admin(true)
      ForumSectionFactory.create &.position(70)

      response = AuthHelper.client_for(admin).post("/api/v1/admin/forum/sections", forum_section: {
        title: "Новый раздел",
      })

      response.status_code.should eq 201
      JSON.parse(response.body)["position"].as_i64.should eq 80
    end

    it "creates a subsection under a root section" do
      admin = UserFactory.create &.is_admin(true)
      root = ForumSectionFactory.create &.title("Джемы").position(10)

      response = AuthHelper.client_for(admin).post("/api/v1/admin/forum/sections", forum_section: {
        title:       "Джем №1",
        parent_id:   root.id,
        group_title: "Не нужна",
      })

      response.status_code.should eq 201
      body = JSON.parse(response.body)
      body["parent_id"].as_i64.should eq root.id
      body["parent"]["slug"].as_s.should eq root.slug
      body["group_title"].as_nil.should be_nil
      body["depth"].as_i.should eq 1
    end

    it "rejects a subsection of a subsection" do
      admin = UserFactory.create &.is_admin(true)
      root = ForumSectionFactory.create
      child = ForumSectionFactory.create &.parent_id(root.id)

      response = AuthHelper.client_for(admin).post("/api/v1/admin/forum/sections", forum_section: {
        title:     "Третий уровень",
        parent_id: child.id,
      })

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["details"]["parent_id"].as_a.first.as_s.should contain "root section"
    end

    it "rejects an empty title" do
      admin = UserFactory.create &.is_admin(true)

      response = AuthHelper.client_for(admin).post("/api/v1/admin/forum/sections", forum_section: {
        title: " ",
      })

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["details"]["title"].as_a.should_not be_empty
    end

    it "rejects a slug that is already taken" do
      admin = UserFactory.create &.is_admin(true)
      ForumSectionFactory.create &.slug("news")

      response = AuthHelper.client_for(admin).post("/api/v1/admin/forum/sections", forum_section: {
        title: "Новости",
        slug:  "news",
      })

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["details"]["slug"].as_a.should_not be_empty
    end
  end

  describe "PATCH /api/v1/admin/forum/sections/:id" do
    it "updates only the fields that were sent" do
      admin = UserFactory.create &.is_admin(true)
      section = ForumSectionFactory.create &.title("Старое").position(30)

      response = AuthHelper.client_for(admin).patch("/api/v1/admin/forum/sections/#{section.id}", forum_section: {
        title: "Новое",
      })

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["title"].as_s.should eq "Новое"
      body["position"].as_i64.should eq 30
      body["slug"].as_s.should eq section.slug
    end

    it "clears an optional description when an empty string arrives" do
      admin = UserFactory.create &.is_admin(true)
      section = ForumSectionFactory.create &.description("Было")

      response = AuthHelper.client_for(admin).patch("/api/v1/admin/forum/sections/#{section.id}", forum_section: {
        description: "",
      })

      response.status_code.should eq 200
      JSON.parse(response.body)["description"].as_nil.should be_nil
    end

    it "does not change the slug of a section that has topics" do
      admin = UserFactory.create &.is_admin(true)
      section = ForumSectionFactory.create
      ForumTopicFactory.create &.section_id(section.id)

      response = AuthHelper.client_for(admin).patch("/api/v1/admin/forum/sections/#{section.id}", forum_section: {
        slug: "new-address",
      })

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["details"]["slug"].as_a.first.as_s.should contain "can not be changed"
    end

    it "does not change the projects section slug" do
      admin = UserFactory.create &.is_admin(true)
      section = ForumSectionFactory.create &.slug("projects")

      response = AuthHelper.client_for(admin).patch("/api/v1/admin/forum/sections/#{section.id}", forum_section: {
        slug: "project-chat",
      })

      response.status_code.should eq 422
    end

    it "does not change the slug of a section with subsections" do
      admin = UserFactory.create &.is_admin(true)
      root = ForumSectionFactory.create
      ForumSectionFactory.create &.parent_id(root.id)

      response = AuthHelper.client_for(admin).patch("/api/v1/admin/forum/sections/#{root.id}", forum_section: {
        slug: "new-address",
      })

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["details"]["slug"].as_a.first.as_s.should contain "can not be changed"
    end

    it "moves a child section to another root" do
      admin = UserFactory.create &.is_admin(true)
      first_root = ForumSectionFactory.create &.position(10)
      second_root = ForumSectionFactory.create &.position(20)
      child = ForumSectionFactory.create &.parent_id(first_root.id)

      response = AuthHelper.client_for(admin).patch("/api/v1/admin/forum/sections/#{child.id}", forum_section: {
        parent_id: second_root.id,
      })

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["parent_id"].as_i64.should eq second_root.id
      body["parent"]["slug"].as_s.should eq second_root.slug
    end

    it "does not make a root with subsections a child" do
      admin = UserFactory.create &.is_admin(true)
      root = ForumSectionFactory.create
      ForumSectionFactory.create &.parent_id(root.id)
      other_root = ForumSectionFactory.create

      response = AuthHelper.client_for(admin).patch("/api/v1/admin/forum/sections/#{root.id}", forum_section: {
        parent_id: other_root.id,
      })

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["details"]["parent_id"].as_a.first.as_s.should contain "subsections"
    end

    it "keeps protected sections at the root" do
      admin = UserFactory.create &.is_admin(true)
      section = ForumSectionFactory.create &.slug("projects")
      root = ForumSectionFactory.create

      response = AuthHelper.client_for(admin).patch("/api/v1/admin/forum/sections/#{section.id}", forum_section: {
        parent_id: root.id,
      })

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["details"]["parent_id"].as_a.first.as_s.should contain "protected"
    end

    it "returns 404 for a missing section" do
      admin = UserFactory.create &.is_admin(true)

      response = AuthHelper.client_for(admin).patch("/api/v1/admin/forum/sections/999999", forum_section: {
        title: "Новое",
      })

      response.status_code.should eq 404
    end
  end

  describe "DELETE /api/v1/admin/forum/sections/:id" do
    it "deletes an empty section" do
      admin = UserFactory.create &.is_admin(true)
      section = ForumSectionFactory.create

      response = AuthHelper.client_for(admin).delete("/api/v1/admin/forum/sections/#{section.id}")

      response.status_code.should eq 204
      ForumSectionQuery.new.id(section.id).first?.should be_nil
    end

    it "refuses to delete a section with topics" do
      admin = UserFactory.create &.is_admin(true)
      section = ForumSectionFactory.create
      ForumTopicFactory.create &.section_id(section.id)

      response = AuthHelper.client_for(admin).delete("/api/v1/admin/forum/sections/#{section.id}")

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "section_not_empty"
      ForumSectionQuery.new.id(section.id).first?.should_not be_nil
    end

    it "refuses to delete a section with subsections" do
      admin = UserFactory.create &.is_admin(true)
      root = ForumSectionFactory.create
      ForumSectionFactory.create &.parent_id(root.id)

      response = AuthHelper.client_for(admin).delete("/api/v1/admin/forum/sections/#{root.id}")

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "section_has_children"
      ForumSectionQuery.new.id(root.id).first?.should_not be_nil
    end

    it "refuses to delete the projects section" do
      admin = UserFactory.create &.is_admin(true)
      section = ForumSectionFactory.create &.slug("projects")

      response = AuthHelper.client_for(admin).delete("/api/v1/admin/forum/sections/#{section.id}")

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "protected_section"
    end

    it "forbids regular users" do
      section = ForumSectionFactory.create

      response = AuthHelper.client_for(UserFactory.create).delete("/api/v1/admin/forum/sections/#{section.id}")

      response.status_code.should eq 403
      ForumSectionQuery.new.id(section.id).first?.should_not be_nil
    end
  end
end
