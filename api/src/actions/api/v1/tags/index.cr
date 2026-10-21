class Api::V1::Tags::Index < ApiAction
  include Api::Auth::SkipRequireSession

  get "/api/v1/tags" do
    tags = TagQuery.new.alphabetical.results
    json({items: tags.map { |tag| TagSerializer.new(tag) }})
  end
end
