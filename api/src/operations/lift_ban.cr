class LiftBan < Avram::Operation
  needs ban : UserBan
  needs moderator : User

  def run
    UserBan::SaveOperation.update!(
      ban,
      lifted_at: Time.utc,
      lifted_by_id: moderator.id,
    )
  end
end
