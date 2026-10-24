require "./spec_helper"

describe FeedText do
  describe ".to_text" do
    it "strips Markdown markers the same way the web snippets do" do
      source = <<-MD
        ## Заголовок

        **Жирный** текст, [ссылка](https://example.com) и `код`.

        ![картинка](/media/a.png)

        :::spoiler Спойлер
        Скрытый текст
        :::
        MD

      text = FeedText.to_text(source)

      text.should contain "Заголовок"
      text.should contain "Жирный текст, ссылка и код."
      text.should contain "Скрытый текст"
      text.should_not contain "**"
      text.should_not contain "https://example.com"
      text.should_not contain "картинка"
      text.should_not contain ":::"
    end

    it "returns an empty string for nil" do
      FeedText.to_text(nil).should eq ""
    end
  end

  describe ".excerpt" do
    it "shortens long text at a word boundary" do
      text = FeedText.excerpt("слово " * 200, 50)

      text.size.should be <= 51
      text.ends_with?("…").should be_true
    end

    it "keeps short text unchanged" do
      FeedText.excerpt("Короткий текст", 50).should eq "Короткий текст"
    end
  end
end
