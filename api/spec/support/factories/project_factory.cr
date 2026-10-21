class ProjectFactory < Avram::Factory
  def initialize
    number = sequence("test-project")
    title "Test Project #{number}"
    slug "test-project-#{number}"
    kind "game"
    status "draft"
    user_id UserFactory.create.id
  end
end
