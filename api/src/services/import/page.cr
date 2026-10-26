module Import
  # What an extractor read from the page, before the model touches it.
  record Page,
    source_url : String,
    host : String,
    title : String,
    description : String,
    text : String,
    images : Array(String),
    links : Array({String, String}) do
    # Nothing to work with: no title and almost no text. The import stops with a
    # readable reason instead of creating a draft full of guesses.
    def thin? : Bool
      title.size < 2 || text.size < 120
    end

    def with_text(value : String) : Page
      Page.new(source_url, host, title, description, value, images, links)
    end
  end
end
