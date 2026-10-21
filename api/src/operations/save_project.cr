class SaveProject < Project::SaveOperation
  permit_columns kind, title, tagline, description

  before_save do
    normalize
    validate_required title
    validate_size_of title, max: 120
    validate_size_of tagline, max: 160
    validate_size_of description, max: 20_000
    validate_kind

    if slug.value.to_s.empty?
      slug.value = Slugify.unique_project_slug(title.value.to_s)
    end
  end

  private def normalize
    title.value = title.value.to_s.strip
    tagline.value = tagline.value.to_s.strip
    description.value = description.value.to_s.strip
    kind.value = "game" if kind.value.to_s.strip.empty?
    status.value = "draft" if status.value.to_s.strip.empty?
  end

  private def validate_kind
    unless %w[game tool asset].includes?(kind.value.to_s)
      kind.add_error "must be game, tool or asset"
    end
  end
end
