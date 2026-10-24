class JamFactory < Avram::Factory
  def initialize
    number = sequence("test-jam")
    title "Test Jam #{number}"
    slug "test-jam-#{number}"
    tagline "A test jam"
    description "Jam description"
    starts_at Time.utc - 1.day
    submissions_close_at Time.utc + 1.day
    voting_closes_at Time.utc + 2.days
    time_zone "Europe/Moscow"
    status "draft"
    judging_mode "community"
    score_scale 5
    user_id UserFactory.create.id
  end
end
