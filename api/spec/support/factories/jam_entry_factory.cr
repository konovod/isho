class JamEntryFactory < Avram::Factory
  def initialize
    jam_id JamFactory.create(&.status("published").published_at(Time.utc)).id
    project_id ProjectFactory.create(&.status("published").published_at(Time.utc)).id
    user_id UserFactory.create.id
    status "submitted"
  end
end
