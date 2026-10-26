require "../spec_helper"

SAMPLE_PAGE = <<-HTML
  <!doctype html>
  <html>
  <head>
    <title>Заголовок из title</title>
    <meta property="og:title" content="Странник &amp; Кот">
    <meta property="og:description" content="Короткое описание &laquo;игры&raquo;">
    <meta property="og:image" content="/media/cover.png">
    <script type="application/ld+json">
      {"@type": "VideoGame", "name": "Странник и Кот", "description": "Из JSON-LD",
       "image": [{"url": "https://cdn.example.com/ld.jpg"}], "genre": "Adventure"}
    </script>
  </head>
  <body>
    <script>var secret = "этот текст не должен попасть";</script>
    <h1>Об игре</h1>
    <p>Странник и кот идут через заброшенный город. Текст достаточно длинный,
       чтобы страница не считалась пустой при разборе.</p>
    <img src="shot1.png" data-src="https://cdn.example.com/shot2.webp">
    <a href="/gallery/full.jpg"><img src="/gallery/preview.jpg"></a>
    <a href="/download/build.zip">Скачать сборку</a>
  </body>
  </html>
  HTML

describe Import::Extractor do
  it "reads the page through the generic reader" do
    page = Import::Extractor.extract(URI.parse("https://example.com/game/"), SAMPLE_PAGE)

    page.title.should eq "Странник & Кот"
    page.description.should eq "Короткое описание «игры»"
    page.text.should contain "Об игре"
    page.text.should contain "Странник и кот"
    page.text.should_not contain "этот текст не должен попасть"
    page.thin?.should be_false

    page.images.should contain "https://example.com/media/cover.png"
    page.images.should contain "https://cdn.example.com/ld.jpg"
    page.images.should contain "https://cdn.example.com/shot2.webp"
    page.images.should contain "https://example.com/game/shot1.png"
    page.images.should contain "https://example.com/gallery/full.jpg"
    page.images.uniq.size.should eq page.images.size

    link = page.links.find { |(url, _)| url == "https://example.com/download/build.zip" }
    link.should_not be_nil
    link.not_nil![1].should eq "Скачать сборку"
  end

  it "reports a page with nothing to read as thin" do
    page = Import::Extractor.extract(URI.parse("https://example.com/empty"), "<html><body></body></html>")
    page.thin?.should be_true
  end

  it "reads Steam through its store API" do
    import_fake.stub(
      "https://store.steampowered.com/api/appdetails?appids=570&l=russian",
      %({"570":{"success":true,"data":{
        "name":"Dota 2",
        "short_description":"Бесплатная командная игра.",
        "detailed_description":"<h2>Об игре</h2><p>Каждый день в Dota 2 сражаются миллионы игроков.</p>",
        "header_image":"https://cdn.example.com/header.jpg",
        "screenshots":[{"path_full":"https://cdn.example.com/shot1.jpg"}],
        "genres":[{"description":"Экшены"}],
        "developers":["Valve"],
        "release_date":{"coming_soon":false,"date":"9 июл. 2013"},
        "platforms":{"windows":true,"mac":true,"linux":true}
      }}}),
      content_type: "application/json",
    )

    page = Import::Extractor.extract(
      URI.parse("https://store.steampowered.com/app/570/Dota_2/"),
      "<html></html>",
    )

    page.title.should eq "Dota 2"
    page.description.should eq "Бесплатная командная игра."
    page.text.should contain "Жанры: Экшены"
    page.text.should contain "Разработчик: Valve"
    page.images.first.should eq "https://cdn.example.com/header.jpg"
    page.images.should contain "https://cdn.example.com/shot1.jpg"
    page.links.should be_empty
  end

  it "rejects a link that redirects to localhost" do
    import_fake.stub_redirect("https://example.com/game/", "http://localhost/admin")

    expect_raises(Import::UrlGuard::Blocked) do
      Import::Fetcher.page("https://example.com/game/")
    end
  end

  it "rejects an answer that is not a page" do
    import_fake.stub("https://example.com/file.zip", "PK", content_type: "application/zip")

    expect_raises(Import::Failed) do
      Import::Fetcher.page("https://example.com/file.zip")
    end
  end

  it "rejects a compressed answer it cannot read" do
    import_fake.responses["https://example.com/game/"] = Import::Transport::Response.new(
      200,
      HTTP::Headers{"Content-Type" => "text/html", "Content-Encoding" => "gzip"},
      "compressed".to_slice,
    )

    expect_raises(Import::Failed) do
      Import::Fetcher.page("https://example.com/game/")
    end
  end
end
