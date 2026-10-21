class UserFactory < Avram::Factory
  def initialize
    email "#{sequence("test-email")}@example.com"
    username "user#{sequence("test-username")}"
    display_name "Test User"
    encrypted_password Authentic.generate_encrypted_password("password1234")
    is_admin false
  end
end
