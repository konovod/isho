class TagSerializer < BaseSerializer
  def initialize(@tag : Tag)
  end

  def render
    {id: @tag.id, name: @tag.name, slug: @tag.slug}
  end
end
