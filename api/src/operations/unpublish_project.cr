class UnpublishProject < Project::SaveOperation
  permit_columns moderation_note
  needs moderator : User

  before_save do
    moderation_note.value = moderation_note.value.to_s.strip

    validate_required moderation_note
    validate_size_of moderation_note, max: 500

    status.value = "draft"
    published_at.value = nil
    moderated_at.value = Time.utc
    moderated_by_id.value = moderator.id
  end
end
