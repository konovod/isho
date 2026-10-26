require "../../../../spec_helper"
require "base64"

module ImportSpecFixtures
  # 1x1 transparent PNG, enough for ImageMagick to process.
  IMAGE = Base64.decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lk3Y9AAAAABJRU5ErkJggg==")

  PAGE = <<-HTML
    <!doctype html>
    <html>
    <head>
      <title>Странник и Кот</title>
      <meta property="og:title" content="Странник и Кот">
      <meta property="og:description" content="Уютное приключение в заброшенном городе.">
      <meta property="og:image" content="https://example.com/cover.png">
    </head>
    <body>
      <h1>Об игре</h1>
      <p>Странник и кот идут через заброшенный город, решают загадки и находят
         странные вещи. Здесь достаточно текста, чтобы страница не считалась пустой.</p>
      <a href="https://example.com/build.zip">Скачать сборку для Windows</a>
    </body>
    </html>
    HTML

  DESCRIPTION = "Странник и кот идут через заброшенный город и решают загадки. " \
                "Каждый вечер город меняется, а находки остаются. " \
                "Игра про тишину, свет и маленькие открытия. " \
                "Подходит для спокойного вечера, проходится за пару часов. "

  def self.answer(overrides = {} of String => String) : String
    payload = {
      "title"              => "Странник и Кот",
      "tagline"            => "Уютное приключение в заброшенном городе",
      "description"        => DESCRIPTION,
      "kind"               => "game",
      "dev_status"         => "beta",
      "genre"              => "adventure",
      "nsfw"               => false,
      "tags"               => ["Unity"],
      "screenshot_indexes" => [0],
      "download_url"       => "https://example.com/build.zip",
      "confidence"         => 0.9,
    }.merge(overrides)

    payload.to_json
  end

  def self.stub_page : Nil
    import_fake.stub("https://example.com/game/", PAGE)
    import_fake.stub_bytes("https://example.com/cover.png", IMAGE, "image/png")
  end
end

describe Api::V1::Projects::Imports do
  it "builds a draft, tags, a download and screenshots" do
    user = UserFactory.create
    SaveTag.create!(name: "Unity")
    ai_fake.completion_text = ImportSpecFixtures.answer
    ImportSpecFixtures.stub_page

    response = AuthHelper.client_for(user).post("/api/v1/projects/imports", import: {
      source_url: "https://example.com/game/",
    })

    response.status_code.should eq 202
    job_id = JSON.parse(response.body)["import"]["id"].as_i64

    Import::Worker.process_one.should be_true

    job = ImportJobQuery.new.id(job_id).first?.not_nil!
    job.status.should eq "done"
    job.step.should eq "done"
    job.attempts.should eq 1

    project = ProjectQuery.new.id(job.project_id.not_nil!).preload_screenshots.preload_downloads.preload_tags.first?.not_nil!
    project.title.should eq "Странник и Кот"
    project.dev_status.should eq "beta"
    project.genre.should eq "adventure"
    project.status.should eq "draft"
    project.source_url.should eq "https://example.com/game/"
    project.tags.map(&.name).should eq ["Unity"]
    project.screenshots.size.should eq 1
    project.screenshots.first.is_cover.should be_true
    project.downloads.size.should eq 1
    project.downloads.first.url.should eq "https://example.com/build.zip"

    JSON.parse(job.result.not_nil!)["title"].as_s.should eq "Странник и Кот"
  end

  it "sends the page text to the model, not the link" do
    user = UserFactory.create
    SaveTag.create!(name: "Unity")
    ai_fake.completion_text = ImportSpecFixtures.answer
    ImportSpecFixtures.stub_page

    AuthHelper.client_for(user).post("/api/v1/projects/imports", import: {
      source_url: "https://example.com/game/",
    })
    Import::Worker.process_one

    request = ai_fake.requests.last
    request.should contain "заброшенный город"
    request.should contain "Кандидаты скриншотов"
  end

  it "reports the draft while the page polls" do
    user = UserFactory.create
    SaveTag.create!(name: "Unity")
    ai_fake.completion_text = ImportSpecFixtures.answer
    ImportSpecFixtures.stub_page

    created = AuthHelper.client_for(user).post("/api/v1/projects/imports", import: {
      source_url: "https://example.com/game/",
    })
    job_id = JSON.parse(created.body)["import"]["id"].as_i64
    Import::Worker.process_one

    response = AuthHelper.client_for(user).get("/api/v1/projects/imports/#{job_id}")
    response.status_code.should eq 200
    JSON.parse(response.body)["import"]["project_slug"].as_s.should eq "strannik-i-kot"

    slug = JSON.parse(response.body)["import"]["project_slug"].as_s
    project = AuthHelper.client_for(user).get("/api/v1/projects/#{slug}")
    project.status_code.should eq 200
    JSON.parse(project.body)["source_url"].as_s.should eq "https://example.com/game/"
  end

  it "never fetches a local address" do
    user = UserFactory.create

    response = AuthHelper.client_for(user).post("/api/v1/projects/imports", import: {
      source_url: "http://localhost/admin",
    })

    response.status_code.should eq 422
    JSON.parse(response.body)["error"]["code"].as_s.should eq "invalid_url"
    ImportJobQuery.new.select_count.should eq 0
  end

  it "needs a confirmed address" do
    user = UserFactory.create &.unconfirmed

    response = AuthHelper.client_for(user).post("/api/v1/projects/imports", import: {
      source_url: "https://example.com/game/",
    })

    response.status_code.should eq 403
    ImportJobQuery.new.select_count.should eq 0
  end

  it "is off when the switch is off" do
    user = UserFactory.create
    ENV["IMPORT_ENABLED"] = "off"

    response = AuthHelper.client_for(user).post("/api/v1/projects/imports", import: {
      source_url: "https://example.com/game/",
    })

    response.status_code.should eq 503
  end

  it "allows one import per account at a time" do
    user = UserFactory.create

    AuthHelper.client_for(user).post("/api/v1/projects/imports", import: {
      source_url: "https://example.com/game/",
    })

    response = AuthHelper.client_for(user).post("/api/v1/projects/imports", import: {
      source_url: "https://example.com/other/",
    })

    response.status_code.should eq 422
    JSON.parse(response.body)["error"]["code"].as_s.should eq "import_in_progress"
  end

  it "hides somebody else's job" do
    owner = UserFactory.create
    stranger = UserFactory.create

    created = AuthHelper.client_for(owner).post("/api/v1/projects/imports", import: {
      source_url: "https://example.com/game/",
    })
    job_id = JSON.parse(created.body)["import"]["id"].as_i64

    response = AuthHelper.client_for(stranger).get("/api/v1/projects/imports/#{job_id}")
    response.status_code.should eq 404
  end

  it "stops a cancelled import before the draft is created" do
    user = UserFactory.create
    ImportSpecFixtures.stub_page

    created = AuthHelper.client_for(user).post("/api/v1/projects/imports", import: {
      source_url: "https://example.com/game/",
    })
    job_id = JSON.parse(created.body)["import"]["id"].as_i64

    AuthHelper.client_for(user).delete("/api/v1/projects/imports/#{job_id}")

    Import::Worker.process_one.should be_false
    ImportJobQuery.new.id(job_id).first?.not_nil!.status.should eq "cancelled"
    ProjectQuery.new.select_count.should eq 0
  end

  it "gives up on a page that cannot be read" do
    user = UserFactory.create
    ai_fake.completion_text = ImportSpecFixtures.answer
    import_fake.stub("https://example.com/game/", "<html><body></body></html>")

    created = AuthHelper.client_for(user).post("/api/v1/projects/imports", import: {
      source_url: "https://example.com/game/",
    })
    job_id = JSON.parse(created.body)["import"]["id"].as_i64

    Import::Worker.process_one.should be_true

    job = ImportJobQuery.new.id(job_id).first?.not_nil!
    job.status.should eq "skipped"
    job.error.not_nil!.should contain "текста"
    ProjectQuery.new.select_count.should eq 0
  end
end
