class Api::V1::Tags::Index < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Projects::CatalogFilters

  MAX_LIMIT = 500

  # The catalogue shows only tags that actually group projects: a tag used by a
  # single game says nothing about the catalogue. This also hides adult tags
  # from visitors, because adult projects do not count towards popularity for
  # them and the tag therefore stays below the threshold. While a filter is
  # active the page asks for `min_projects=1`, so a rare combination that still
  # has a project behind it stays reachable.
  DEFAULT_MIN_PROJECTS = 2

  get "/api/v1/tags" do
    limit = params.get?(:limit).try(&.to_i?).try(&.clamp(1, MAX_LIMIT))
    min_projects = params.get?(:min_projects).try(&.to_i?).try(&.clamp(1, MAX_LIMIT)) || DEFAULT_MIN_PROJECTS
    viewer = current_user?

    query = TagQuery.new
    if term = params.get?(:q).try(&.strip)
      query = query.search(term) unless term.empty?
    end

    counts = tag_counts(catalog_query(viewer))
    selected = filter_tags
    selected_ids = selected.map(&.id)

    # Only tags the filtered catalogue still has: this is what makes the strip
    # show compatible tags instead of every tag in the catalogue.
    ranked = query.results
      .reject { |tag| selected_ids.includes?(tag.id) }
      .select { |tag| counts.fetch(tag.id, 0_i64) >= min_projects }
      .sort do |left, right|
        by_count = counts.fetch(right.id, 0_i64) <=> counts.fetch(left.id, 0_i64)
        by_count == 0 ? left.name.downcase <=> right.name.downcase : by_count
      end

    # Selected tags are pinned in the order the visitor picked them, even when
    # the tag search, the popularity threshold or an empty combination would
    # hide them: otherwise a chip would disappear and there would be no way to
    # undo just that filter. The check runs over the unfiltered catalogue, so a
    # hidden 18+ tag does not surface to a visitor who guessed its slug.
    visible = tag_counts(ProjectQuery.new.visible_to(viewer))
    pinned = selected
      .select { |tag| visible.fetch(tag.id, 0_i64) > 0 }
      .map { |tag| TagWithCountSerializer.new(tag, counts.fetch(tag.id, 0_i64)) }

    others = ranked.map { |tag| TagWithCountSerializer.new(tag, counts.fetch(tag.id, 0_i64)) }
    others = others.first({limit - pinned.size, 0}.max) if limit

    json({
      items: pinned + others,
      meta:  {total: pinned.size + ranked.size},
    })
  end

  # Counts are taken over the same catalogue the project list would return,
  # selected tags and the type/browser filters included.
  private def tag_counts(catalog : ProjectQuery) : Hash(Int64, Int64)
    counts = {} of Int64 => Int64
    ProjectTagQuery.new
      .join_project(catalog)
      .group(&.tag_id)
      .group_count
      .each { |key, count| counts[key.first.as(Int64)] = count }
    counts
  end
end
