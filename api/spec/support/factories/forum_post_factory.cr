class ForumPostFactory < Avram::Factory
  def initialize
    number = sequence("test-forum-post")
    body "Test forum post #{number}"
    topic_id ForumTopicFactory.create.id
    user_id UserFactory.create.id
  end
end
