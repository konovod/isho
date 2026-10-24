class DeleteJam < Avram::Operation
  needs jam : Jam

  def run
    # Latch stores the banner outside the database.
    jam.banner.try(&.delete)
    Jam::DeleteOperation.delete!(jam)
  end
end
