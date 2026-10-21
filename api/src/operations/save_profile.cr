class SaveProfile < User::SaveOperation
  permit_columns display_name, bio

  before_save do
    name = display_name.value.to_s.strip
    display_name.value = name.empty? ? nil : name

    bio.value = bio.value.to_s.strip
    validate_size_of display_name, max: 60
    validate_size_of bio, max: 2_000
  end
end
