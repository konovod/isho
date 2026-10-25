class Api::V1::Projects::Index < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Projects::CatalogFilters

  get "/api/v1/projects" do
    page = (params.get?(:page).try(&.to_i?) || 1).clamp(1, 10_000)
    per_page = (params.get?(:per_page).try(&.to_i?) || AppSettings::PROJECTS_PER_PAGE).clamp(1, 48)

    query = catalog_query(current_user?).newest

    if term = params.get?(:q).try(&.strip)
      query = query.search(term) unless term.empty?
    end

    # `?tag=` is the old single-tag address; `?tags=a,b` replaces it when the
    # visitor picks more than one. Old links and feeds keep working.
    if legacy_slug = params.get?(:tag).try(&.strip)
      if filter_tag_slugs.empty? && !legacy_slug.empty?
        tag = TagQuery.new.slug(legacy_slug).first?
        query = tag ? query.with_all_tags([tag.id]) : query.id.eq(-1_i64)
      end
    end

    total = query.clone.select_count
    projects = query
      .preload_user
      .preload_screenshots
      .preload_tags
      .preload_builds
      .limit(per_page)
      .offset((page - 1) * per_page)
      .results

    json({
      items: projects.map { |project| ProjectSerializer.new(project) },
      meta:  {page: page, per_page: per_page, total: total},
    })
  end
end
