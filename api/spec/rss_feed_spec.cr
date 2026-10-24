require "./spec_helper"
require "xml"

describe RssFeed do
  it "escapes user content and keeps the document well formed" do
    now = Time.utc(2026, 10, 24, 12, 0, 0)
    feed = RssFeed.new(
      title: "И.ШО — тест",
      link: "https://example.com/",
      description: "Проверка & экранирования",
      self_url: "https://example.com/feed.rss",
      items: [
        RssFeed::Item.new(
          title: %(Игра "Rock & Roll" <beta>),
          link: "https://example.com/p/game",
          guid: "isho:project:1",
          published_at: now,
          creator: "Автор & Ко",
          description: "Строка\u0001 с управляющим символом",
          categories: ["RPG & квест"],
        ),
      ],
    )

    body = feed.to_xml
    document = XML.parse(body)

    document.first_element_child.not_nil!.name.should eq "rss"
    body.should contain "&amp;"
    body.should contain "&lt;beta&gt;"
    body.should contain "&quot;Rock &amp; Roll&quot;"
    body.should_not contain "\u0001"
    body.should contain "Sat, 24 Oct 2026 12:00:00 +0000"
  end

  it "formats dates as RFC 822 in UTC" do
    RssFeed.rfc822(Time.utc(2026, 1, 2, 3, 4, 5)).should eq "Fri, 02 Jan 2026 03:04:05 +0000"
  end
end
