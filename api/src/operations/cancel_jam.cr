class CancelJam < Avram::Operation
  needs jam : Jam
  needs reason : String

  def run
    Jam::SaveOperation.update!(
      jam,
      status: "canceled",
      canceled_at: Time.utc,
      cancel_reason: reason,
    )
  end
end
