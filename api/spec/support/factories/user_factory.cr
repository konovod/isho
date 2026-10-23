class UserFactory < Avram::Factory
  def initialize
    email "#{sequence("test-email")}@example.com"
    username "user#{sequence("test-username")}"
    display_name "Test User"
    encrypted_password Authentic.generate_encrypted_password("password1234")
    theme "dark"
    show_nsfw true
    max_ai_usage "full"
    is_admin false
    ai_flair_enabled true
    email_confirmed_at Time.utc
  end

  # Sign-up leaves the address unconfirmed until the link in the letter is
  # opened; use this for tests about publishing and forum access.
  def unconfirmed
    email_confirmed_at nil
  end
end
