class ForumTopicFactory < Avram::Factory
  def initialize
    number = sequence("test-forum-topic")
    title "Test Topic #{number}"
    slug "test-topic-#{number}"
    section_id ForumSectionFactory.create.id
    user_id UserFactory.create.id
    replies_count 0
    last_post_at Time.utc
  end
end
