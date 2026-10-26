class PrivateMessageFactory < Avram::Factory
  def initialize
    number = sequence("test-private-message")
    body "Test private message #{number}"
    sender_id UserFactory.create.id
    recipient_id UserFactory.create.id
    delivered true
  end
end
