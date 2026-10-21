class SaveDevlog < Devlog::SaveOperation
  permit_columns title, body

  before_save do
    normalize
    validate_required title
    validate_required body
    validate_size_of title, max: 120
    validate_size_of body, max: 50_000

    if slug.value.to_s.empty?
      slug.value = if project_id.value
                     Slugify.unique_devlog_slug(project_id.value.not_nil!, title.value.to_s)
                   else
                     Slugify.call(title.value.to_s, "devlog")
                   end
    end
  end

  private def normalize
    title.value = title.value.to_s.strip
    body.value = body.value.to_s.strip
  end
end
