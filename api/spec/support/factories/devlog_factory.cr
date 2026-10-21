class DevlogFactory < Avram::Factory
  def initialize
    number = sequence("test-devlog")
    title "Test Devlog #{number}"
    slug "test-devlog-#{number}"
    body "A short devlog body"
    project_id ProjectFactory.create.id
  end
end
