class SaveJamCriterion < JamCriterion::SaveOperation
  permit_columns title, description, weight, position

  before_save do
    title.value = title.value.to_s.strip
    description.value = blank_to_nil(description.value)
    weight.value = 1 if weight.value.nil?
    position.value = next_position if position.value.nil?

    validate_required title
    validate_size_of title, max: AppSettings::JAM_CRITERION_TITLE_MAX
    validate_size_of description, max: AppSettings::JAM_CRITERION_DESC_MAX
    validate_weight
    validate_limit
  end

  private def blank_to_nil(value : String?) : String?
    text = value.to_s.strip
    text.empty? ? nil : text
  end

  private def validate_weight
    value = weight.value || 1
    unless (1..3).includes?(value)
      weight.add_error "must be between 1 and 3"
    end
  end

  private def validate_limit
    return if record
    return if criteria_count < AppSettings::JAM_CRITERIA_MAX

    title.add_error "can not have more than #{AppSettings::JAM_CRITERIA_MAX} criteria"
  end

  private def next_position : Int32
    id = record.try(&.jam_id) || jam_id.value
    return 0 unless id

    last = JamCriterionQuery.new.for_jam(id).position.desc_order.first?
    (last.try(&.position) || 0) + 10
  end

  private def criteria_count : Int64
    id = record.try(&.jam_id) || jam_id.value
    return 0_i64 unless id

    JamCriterionQuery.new.for_jam(id).select_count
  end
end
