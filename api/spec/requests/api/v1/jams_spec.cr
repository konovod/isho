require "../../../spec_helper"

module JamBannerUploadHelper
  # 1x1 transparent PNG, enough for ImageMagick to process.
  PNG = Base64.decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lk3Y9AAAAABJRU5ErkJggg==")

  def self.upload(
    client : ApiClient,
    slug : String,
    bytes : Bytes = PNG,
    filename : String = "banner.png",
    content_type : String = "image/png",
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
      .exec_raw(Api::V1::Jams::Banner.with(slug), body.to_s)
  end
end

describe Api::V1::Jams do
  describe "POST /api/v1/jams" do
    it "creates a draft jam for a confirmed user" do
      user = UserFactory.create

      response = AuthHelper.client_for(user).post("/api/v1/jams", jam: {
        title: "Зимний джем",
      })

      response.status_code.should eq 201
      body = JSON.parse(response.body)
      body["status"].as_s.should eq "draft"
      body["slug"].as_s.should eq "zimniy-dzhem"
      body["organizer"]["username"].as_s.should eq user.username
      body["viewer"]["is_organizer"].as_bool.should be_true
      body["criteria"].as_a.should be_empty
      body["forum_section"].as_nil.should be_nil
    end

    it "requires a confirmed email" do
      user = UserFactory.create &.unconfirmed

      response = AuthHelper.client_for(user).post("/api/v1/jams", jam: {
        title: "Зимний джем",
      })

      response.status_code.should eq 403
      JSON.parse(response.body)["error"]["code"].as_s.should eq "email_not_confirmed"
    end
  end

  describe "GET /api/v1/jams" do
    it "lists only published jams" do
      JamFactory.create
      published = JamFactory.create &.status("published").published_at(Time.utc)

      response = ApiClient.new.get("/api/v1/jams")

      response.status_code.should eq 200
      items = JSON.parse(response.body)["items"].as_a
      items.map(&.["slug"].as_s).should eq [published.slug]
    end

    it "filters by phase" do
      now = Time.utc
      JamFactory.create &.status("published").published_at(now).title("Идёт")
        .starts_at(now - 1.day).submissions_close_at(now + 1.day).voting_closes_at(now + 2.days)
      JamFactory.create &.status("published").published_at(now).title("Завершён")
        .starts_at(now - 3.days).submissions_close_at(now - 2.days).voting_closes_at(now - 1.day)

      response = ApiClient.new.get("/api/v1/jams?phase=open")

      response.status_code.should eq 200
      items = JSON.parse(response.body)["items"].as_a
      items.map(&.["title"].as_s).should eq ["Идёт"]
    end
  end

  describe "GET /api/v1/jams/:slug" do
    it "hides a draft from everybody except its organizer" do
      owner = UserFactory.create
      draft = JamFactory.create &.user_id(owner.id).slug("draft-jam")

      ApiClient.new.get("/api/v1/jams/#{draft.slug}").status_code.should eq 404

      response = AuthHelper.client_for(owner).get("/api/v1/jams/#{draft.slug}")
      response.status_code.should eq 200
      JSON.parse(response.body)["status"].as_s.should eq "draft"
    end

    it "hides the theme until the jam starts" do
      now = Time.utc
      jam = JamFactory.create &.status("published").published_at(now).theme("Тайна")
        .starts_at(now + 1.day).submissions_close_at(now + 2.days).voting_closes_at(now + 3.days)

      response = ApiClient.new.get("/api/v1/jams/#{jam.slug}")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["theme"].as_nil.should be_nil
      body["theme_visible"].as_bool.should be_false
      body["phase"].as_s.should eq "upcoming"
    end
  end

  describe "PATCH /api/v1/jams/:slug" do
    it "updates a draft and keeps its existing slug" do
      user = UserFactory.create
      jam = JamFactory.create &.user_id(user.id)

      response = AuthHelper.client_for(user).patch("/api/v1/jams/#{jam.slug}", jam: {
        title: "Летний джем",
      })

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["title"].as_s.should eq "Летний джем"
      body["slug"].as_s.should eq jam.slug
    end

    it "does not change the slug after publication" do
      user = UserFactory.create
      jam = JamFactory.create &.user_id(user.id).status("published").published_at(Time.utc)

      response = AuthHelper.client_for(user).patch("/api/v1/jams/#{jam.slug}", jam: {
        slug: "new-address",
      })

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["details"]["slug"].as_a.first.as_s.should contain "after publication"
    end

    it "returns 404 for a stranger" do
      jam = JamFactory.create

      response = AuthHelper.client_for(UserFactory.create).patch("/api/v1/jams/#{jam.slug}", jam: {
        title: "Чужой джем",
      })

      response.status_code.should eq 404
    end
  end

  describe "POST /api/v1/jams/:slug/publish" do
    it "publishes a jam and creates its forum section under jams" do
      user = UserFactory.create
      jam = JamFactory.create &.user_id(user.id).status("draft")
      JamCriterionFactory.create &.jam_id(jam.id).title("Геймплей")

      response = AuthHelper.client_for(user).post("/api/v1/jams/#{jam.slug}/publish")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["status"].as_s.should eq "published"
      section = body["forum_section"]
      section["slug"].as_s.should start_with "jam-"
      section["title"].as_s.should eq jam.title

      stored = JamQuery.new.id(jam.id).first?.not_nil!
      stored.published?.should be_true
      stored.forum_section_id.should_not be_nil

      forum_section = ForumSectionQuery.new.id(stored.forum_section_id.not_nil!).first?.not_nil!
      parent = ForumSectionQuery.new.id(forum_section.parent_id.not_nil!).first?.not_nil!
      parent.slug.should eq "jams"
      forum_section.ai_answers_enabled.should be_false
    end

    it "refuses to publish without criteria" do
      user = UserFactory.create
      jam = JamFactory.create &.user_id(user.id)
      criterion = JamCriterionFactory.create &.jam_id(jam.id)
      JamCriterion::DeleteOperation.delete!(criterion)

      response = AuthHelper.client_for(user).post("/api/v1/jams/#{jam.slug}/publish")

      response.status_code.should eq 422
      body = JSON.parse(response.body)
      body["error"]["code"].as_s.should eq "jam_not_ready"
      body["error"]["details"]["criteria"].as_a.should_not be_empty
    end

    it "keeps the forum section title in sync with the jam" do
      user = UserFactory.create
      jam = JamFactory.create &.user_id(user.id)
      JamCriterionFactory.create &.jam_id(jam.id)
      client = AuthHelper.client_for(user)

      client.post("/api/v1/jams/#{jam.slug}/publish").status_code.should eq 200
      client.patch("/api/v1/jams/#{jam.slug}", jam: {title: "Новое имя"}).status_code.should eq 200

      stored = JamQuery.new.id(jam.id).first?.not_nil!
      section = ForumSectionQuery.new.id(stored.forum_section_id.not_nil!).first?.not_nil!
      section.title.should eq "Новое имя"
    end

    it "refuses to publish without dates" do
      user = UserFactory.create
      jam = JamFactory.create &.user_id(user.id).starts_at(nil).submissions_close_at(nil).voting_closes_at(nil)
      JamCriterionFactory.create &.jam_id(jam.id)

      response = AuthHelper.client_for(user).post("/api/v1/jams/#{jam.slug}/publish")

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["details"]["starts_at"].as_a.should_not be_empty
    end
  end

  describe "POST /api/v1/jams/:slug/cancel" do
    it "cancels a published jam with a reason" do
      user = UserFactory.create
      jam = JamFactory.create &.user_id(user.id).status("published").published_at(Time.utc)

      response = AuthHelper.client_for(user).post("/api/v1/jams/#{jam.slug}/cancel", jam: {
        cancel_reason: "Недостаточно участников",
      })

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["status"].as_s.should eq "canceled"
      body["cancel_reason"].as_s.should eq "Недостаточно участников"
      body["phase"].as_s.should eq "canceled"
    end
  end

  describe "DELETE /api/v1/jams/:slug" do
    it "deletes a draft" do
      user = UserFactory.create
      jam = JamFactory.create &.user_id(user.id)

      response = AuthHelper.client_for(user).delete("/api/v1/jams/#{jam.slug}")

      response.status_code.should eq 204
      JamQuery.new.id(jam.id).first?.should be_nil
    end

    it "does not delete a published jam" do
      user = UserFactory.create
      jam = JamFactory.create &.user_id(user.id).status("published").published_at(Time.utc)

      response = AuthHelper.client_for(user).delete("/api/v1/jams/#{jam.slug}")

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "jam_not_draft"
    end
  end

  describe "POST /api/v1/jams/:slug/banner" do
    it "uploads a banner and returns its URL" do
      user = UserFactory.create
      jam = JamFactory.create &.user_id(user.id)

      response = JamBannerUploadHelper.upload(AuthHelper.client_for(user), jam.slug)

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["banner_url"].as_s.should_not be_empty
      body["banner_card_url"].as_s.should_not be_empty

      stored = JamQuery.new.id(jam.id).first?.not_nil!
      stored.banner.should_not be_nil
    end

    it "rejects a file that is not an image" do
      user = UserFactory.create
      jam = JamFactory.create &.user_id(user.id)

      response = JamBannerUploadHelper.upload(
        AuthHelper.client_for(user),
        jam.slug,
        "not an image".to_slice,
        "banner.txt",
        "text/plain",
      )

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "invalid_file_type"
    end
  end

  describe "criteria" do
    it "creates, updates and deletes a criterion" do
      user = UserFactory.create
      jam = JamFactory.create &.user_id(user.id)
      client = AuthHelper.client_for(user)

      created = client.post("/api/v1/jams/#{jam.slug}/criteria", jam_criterion: {
        title:  "Атмосфера",
        weight: 2,
      })
      created.status_code.should eq 201
      body = JSON.parse(created.body)
      id = body["id"].as_i64
      body["weight"].as_i.should eq 2
      body["position"].as_i.should be > 0

      updated = client.patch("/api/v1/jams/#{jam.slug}/criteria/#{id}", jam_criterion: {
        title: "Атмосфера и звук",
      })
      updated.status_code.should eq 200
      JSON.parse(updated.body)["title"].as_s.should eq "Атмосфера и звук"

      deleted = client.delete("/api/v1/jams/#{jam.slug}/criteria/#{id}")
      deleted.status_code.should eq 204
      JamCriterionQuery.new.id(id).first?.should be_nil
    end

    it "returns 404 for a criterion of another jam" do
      user = UserFactory.create
      jam = JamFactory.create &.user_id(user.id)
      other = JamCriterionFactory.create

      response = AuthHelper.client_for(user).patch("/api/v1/jams/#{jam.slug}/criteria/#{other.id}", jam_criterion: {
        title: "Чужой критерий",
      })

      response.status_code.should eq 404
    end
  end
end
