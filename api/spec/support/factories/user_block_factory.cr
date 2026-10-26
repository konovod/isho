class UserBlockFactory < Avram::Factory
  def initialize
    blocker_id UserFactory.create.id
    blocked_user_id UserFactory.create.id
  end
end
