class Api::V1::Projects::Index < ApiAction
  include Api::Auth::SkipRequireSession

  get "/api/v1/projects" do
    page = (params.get?(:page).try(&.to_i?) || 1).clamp(1, 10_000)
    per_page = (params.get?(:per_page).try(&.to_i?) || AppSettings::PROJECTS_PER_PAGE).clamp(1, 48)

    query = ProjectQuery.new.visible_to(current_user?).newest

    if term = params.get?(:q).try(&.strip)
      query = query.search(term) unless term.empty?
    end

    if tag_slug = params.get?(:tag).try(&.strip)
      unless tag_slug.empty?
        tag = TagQuery.new.slug(tag_slug).first?
        query = tag ? query.join_project_tags(ProjectTagQuery.new.tag_id(tag.id)) : query.id.eq(-1_i64)
      end
    end

    total = query.clone.select_count
    projects = query
      .preload_user
      .preload_screenshots
      .preload_tags
      .limit(per_page)
      .offset((page - 1) * per_page)
      .results

    json({
      items: projects.map { |project| ProjectSerializer.new(project) },
      meta:  {page: page, per_page: per_page, total: total},
    })
  end
end
