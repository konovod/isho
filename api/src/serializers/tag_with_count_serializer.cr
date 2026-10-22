class TagWithCountSerializer < BaseSerializer
  def initialize(@tag : Tag, @projects_count : Int64)
  end

  def render
    {
      id:             @tag.id,
      name:           @tag.name,
      slug:           @tag.slug,
      projects_count: @projects_count,
    }
  end
end
