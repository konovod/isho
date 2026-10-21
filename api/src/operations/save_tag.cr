class SaveTag < Tag::SaveOperation
  permit_columns name, slug

  MAX_NAME_LENGTH = 40

  before_save do
    name.value = name.value.to_s.strip.gsub(/\s+/, " ")[0, MAX_NAME_LENGTH].strip
    slug.value = Slugify.call(name.value.to_s, "")

    validate_required name
    validate_required slug
    validate_size_of name, max: MAX_NAME_LENGTH
  end
end
