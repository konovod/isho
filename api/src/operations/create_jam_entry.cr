class CreateJamEntry < Avram::Operation
  needs jam : Jam
  needs user : User
  needs project : Project

  def run
    JamEntry::SaveOperation.create!(
      jam_id: jam.id,
      user_id: user.id,
      project_id: project.id,
      status: "submitted",
    )
  end
end
