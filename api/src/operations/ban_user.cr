# Places a ban and lifts whatever ban is still active, so a user never has two
# active rows at once. The old row stays in the history.
class BanUser < Avram::Operation
  param_key :ban
  needs user : User
  needs moderator : User

  attribute reason : String
  attribute days : Int32

  MAX_DAYS = 3650

  def run
    normalize
    validate_reason
    validate_days

    return unless valid?

    AppDatabase.transaction do
      lift_active_bans
      UserBan::SaveOperation.create!(
        user_id: user.id,
        banned_by_id: moderator.id,
        reason: reason.value.to_s,
        expires_at: days.value.not_nil!.days.from_now,
      )
    end
  end

  private def normalize
    reason.value = reason.value.to_s.strip
  end

  private def validate_reason
    validate_required reason
    validate_size_of reason, max: 500
  end

  private def validate_days
    value = days.value

    if value.nil?
      days.add_error "is required"
    elsif value < 1
      days.add_error "must be at least 1"
    elsif value > MAX_DAYS
      days.add_error "must be at most #{MAX_DAYS}"
    end
  end

  private def lift_active_bans
    UserBanQuery.new.for_user(user.id).active.results.each do |ban|
      LiftBan.run!(ban: ban, moderator: moderator)
    end
  end
end
