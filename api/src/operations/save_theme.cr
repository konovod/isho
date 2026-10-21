class SaveTheme < User::SaveOperation
  permit_columns theme

  before_save do
    theme.value = theme.value.to_s.strip.downcase
    validate_inclusion_of theme, in: AppSettings::THEMES
  end
end
