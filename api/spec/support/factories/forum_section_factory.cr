class ForumSectionFactory < Avram::Factory
  def initialize
    number = sequence("test-forum-section")
    title "Test Section #{number}"
    slug "test-section-#{number}"
    description "A test forum section"
    group_title "Тесты"
    position 0
  end
end
