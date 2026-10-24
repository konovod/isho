class ForumPostReactionFactory < Avram::Factory
  def initialize
    post_id ForumPostFactory.create.id
    user_id UserFactory.create.id
    kind ForumPostReaction::LIKE
  end
end
