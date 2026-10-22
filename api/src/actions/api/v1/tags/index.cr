class Api::V1::Tags::Index < ApiAction
  include Api::Auth::SkipRequireSession

  MAX_LIMIT = 500

  get "/api/v1/tags" do
    limit = params.get?(:limit).try(&.to_i?).try(&.clamp(1, MAX_LIMIT))

    query = TagQuery.new
    if term = params.get?(:q).try(&.strip)
      query = query.search(term) unless term.empty?
    end

    counts = published_projects_count_by_tag
    ranked = query.results.sort do |left, right|
      by_count = counts.fetch(right.id, 0_i64) <=> counts.fetch(left.id, 0_i64)
      by_count == 0 ? left.name.downcase <=> right.name.downcase : by_count
    end

    total = ranked.size
    ranked = ranked.first(limit) if limit

    json({
      items: ranked.map { |tag| TagWithCountSerializer.new(tag, counts.fetch(tag.id, 0_i64)) },
      meta:  {total: total},
    })
  end

  private def published_projects_count_by_tag : Hash(Int64, Int64)
    counts = {} of Int64 => Int64
    ProjectTagQuery.new
      .with_published_project
      .group(&.tag_id)
      .group_count
      .each { |key, count| counts[key.first.as(Int64)] = count }
    counts
  end
end
