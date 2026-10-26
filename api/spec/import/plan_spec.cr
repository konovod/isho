require "../spec_helper"

private def sample_page : Import::Page
  Import::Page.new(
    source_url: "https://example.com/game/",
    host: "example.com",
    title: "Странник и Кот",
    description: "Короткое описание",
    text: "Достаточно длинный текст страницы, чтобы страница не считалась пустой.",
    images: [
      "https://example.com/one.png",
      "https://example.com/two.png",
      "https://example.com/three.png",
    ],
    links: [
      {"https://example.com/build.zip", "Скачать сборку"},
      {"https://example.com/about", "О проекте"},
    ],
  )
end

private def ai_answer(
  title : String = "Странник и Кот",
  description : String = "Описание игры. " * 20,
  kind : String = "game",
  genre : String? = "adventure",
  tags : Array(String) = ["Unity"],
  screenshot_indexes : Array(Int32) = [0, 2],
  download_url : String? = "https://example.com/build.zip",
  confidence : Float64 = 0.8,
) : JSON::Any
  JSON.parse(JSON.build do |json|
    json.object do
      json.field "title", title
      json.field "tagline", "Уютное приключение в заброшенном городе"
      json.field "description", description
      json.field "kind", kind
      json.field "dev_status", "beta"
      json.field "genre", genre
      json.field "nsfw", false
      json.field "tags" do
        json.array { tags.each { |tag| json.string(tag) } }
      end
      json.field "screenshot_indexes" do
        json.array { screenshot_indexes.each { |index| json.number(index) } }
      end
      json.field "download_url", download_url
      json.field "confidence", confidence
    end
  end)
end

describe Import::Plan do
  it "builds a draft from a usable answer" do
    SaveTag.create!(name: "Unity")
    tags = TagQuery.new.results

    draft = Import::Plan.from(ai_answer, sample_page, tags).not_nil!

    draft.title.should eq "Странник и Кот"
    draft.kind.should eq "game"
    draft.dev_status.should eq "beta"
    draft.genre.should eq "adventure"
    draft.tags.should eq ["Unity"]
    draft.image_urls.should eq ["https://example.com/one.png", "https://example.com/three.png"]
    draft.download_url.should eq "https://example.com/build.zip"
    draft.download_label.should eq "Скачать сборку"
  end

  it "drops tags that do not exist on the site" do
    SaveTag.create!(name: "Unity")
    tags = TagQuery.new.results

    draft = Import::Plan.from(ai_answer(tags: ["Unity", "Выдуманный", "RPG"]), sample_page, tags).not_nil!
    draft.tags.should eq ["Unity"]
  end

  it "drops a genre it does not know and any genre for a non-game" do
    SaveTag.create!(name: "Unity")
    tags = TagQuery.new.results

    Import::Plan.from(ai_answer(genre: "roguelike"), sample_page, tags)
      .not_nil!.genre.should be_nil

    Import::Plan.from(ai_answer(kind: "tool"), sample_page, tags)
      .not_nil!.genre.should be_nil
  end

  it "keeps only screenshot indexes that exist" do
    SaveTag.create!(name: "Unity")
    tags = TagQuery.new.results

    draft = Import::Plan.from(ai_answer(screenshot_indexes: [99, -1, 1, 1]), sample_page, tags).not_nil!
    draft.image_urls.should eq ["https://example.com/two.png"]
  end

  it "never accepts a download link the page did not have" do
    SaveTag.create!(name: "Unity")
    tags = TagQuery.new.results

    Import::Plan.from(ai_answer(download_url: "https://evil.example/setup.exe"), sample_page, tags)
      .not_nil!.download_url.should be_nil

    Import::Plan.from(ai_answer(download_url: "https://example.com/readme.txt"), sample_page, tags)
      .not_nil!.download_url.should be_nil
  end

  it "strips links and images out of the description" do
    SaveTag.create!(name: "Unity")
    tags = TagQuery.new.results

    text = "Описание игры с ссылкой [на сайт](https://spam.example) и картинкой ![кадр](https://img.example/x.png). " * 8
    draft = Import::Plan.from(ai_answer(description: text), sample_page, tags).not_nil!

    draft.description.not_nil!.should contain "на сайт"
    draft.description.not_nil!.should_not contain "spam.example"
    draft.description.not_nil!.should_not contain "!["
  end

  it "refuses an answer it is not sure about" do
    SaveTag.create!(name: "Unity")
    tags = TagQuery.new.results

    Import::Plan.from(ai_answer(confidence: 0.1), sample_page, tags).should be_nil
  end

  it "falls back to the page title when the model gives none" do
    SaveTag.create!(name: "Unity")
    tags = TagQuery.new.results

    draft = Import::Plan.from(ai_answer(title: ""), sample_page, tags).not_nil!
    draft.title.should eq "Странник и Кот"
  end
end
