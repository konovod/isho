# Filters shared by the catalogue list and its tag strip. Both must use the
# same rules, otherwise the strip offers tags whose combination leads to an
# empty page.
module Api::V1::Projects::CatalogFilters
  MAX_TAGS = 8

  # `?tags=unity,2d` — a slug is always `[a-z0-9-]`, so a comma cannot appear
  # inside one and the list stays unambiguous.
  def filter_tag_slugs : Array(String)
    raw = params.get?(:tags).try(&.strip)
    return [] of String if raw.nil? || raw.empty?

    raw.split(',').map(&.strip).reject(&.empty?).uniq.first(MAX_TAGS)
  end

  # Tags in the order the visitor picked them, so the strip can pin them first.
  memoize def filter_tags : Array(Tag)
    slugs = filter_tag_slugs
    return [] of Tag if slugs.empty?

    by_slug = TagQuery.new.slug.in(slugs).results.index_by(&.slug)
    slugs.compact_map { |slug| by_slug[slug]? }
  end

  def filter_kind : String?
    filter_choice(:kind, AppSettings::PROJECT_KINDS)
  end

  # Development status, not the publication `status` of the project.
  def filter_dev_status : String?
    filter_choice(:dev_status, AppSettings::PROJECT_DEV_STATUSES)
  end

  def filter_genre : String?
    filter_choice(:genre, AppSettings::PROJECT_GENRES)
  end

  def web_build_only? : Bool
    value = params.get?(:web).try(&.strip)
    value == "1" || value == "true"
  end

  # The catalogue a viewer may see, narrowed by the filter strip. An unknown
  # tag slug yields nothing: a stale link must not silently widen the selection
  # to the tags that still exist.
  def catalog_query(viewer : User?) : ProjectQuery
    query = ProjectQuery.new.visible_to(viewer)

    if kind = filter_kind
      query = query.kind(kind)
    end

    if dev_status = filter_dev_status
      query = query.dev_status(dev_status)
    end

    if genre = filter_genre
      query = query.genre(genre)
    end

    query = query.with_web_build if web_build_only?

    slugs = filter_tag_slugs
    return query if slugs.empty?

    tags = filter_tags
    return query.id.eq(-1_i64) unless tags.size == slugs.size

    query.with_all_tags(tags.map(&.id))
  end

  private def filter_choice(name : Symbol, allowed : Array(String)) : String?
    value = params.get?(name).try(&.strip)
    return nil unless value

    allowed.includes?(value) ? value : nil
  end
end
