# Attaches tags to a project by name. Existing tags are matched by name
# (case-insensitive) or by slug; unknown names create new tags.
class SetProjectTags < Avram::Operation
  needs project : Project
  needs tag_names : Array(String)

  MAX_TAGS        =  8
  MAX_NAME_LENGTH = 40

  def run
    tags = resolved_tags

    ProjectTagQuery.new.project_id(project.id).delete
    tags.each do |tag|
      ProjectTag::SaveOperation.create!(project_id: project.id, tag_id: tag.id)
    end
  end

  private def resolved_tags : Array(Tag)
    existing = TagQuery.new.results
    by_name = {} of String => Tag
    by_slug = {} of String => Tag

    existing.each do |tag|
      by_name[tag.name.downcase] = tag
      by_slug[tag.slug] = tag
    end

    normalized_names.compact_map do |name|
      slug = Slugify.call(name, "")
      next if slug.empty?

      tag = by_name[name.downcase]? || by_slug[slug]?
      if tag.nil?
        tag = create_tag(name, slug)
        by_name[tag.name.downcase] = tag
        by_slug[tag.slug] = tag
      end
      tag
    end.uniq(&.id)
  end

  private def normalized_names : Array(String)
    tag_names
      .map { |name| normalize_name(name) }
      .reject(&.empty?)
      .uniq(&.downcase)
      .first(MAX_TAGS)
  end

  private def normalize_name(name : String) : String
    name.strip.gsub(/\s+/, " ")[0, MAX_NAME_LENGTH].strip
  end

  # Two authors may create the same tag at the same time: the unique index on
  # slug wins, and the losing request reuses the tag that was just created.
  private def create_tag(name : String, slug : String) : Tag
    SaveTag.create!(name: name)
  rescue error : PG::Error
    TagQuery.new.slug(slug).first? || raise error
  end
end
