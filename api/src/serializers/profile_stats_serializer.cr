class ProfileStatsSerializer < BaseSerializer
  def initialize(@counts : ProfileStats::Counts)
  end

  def render
    {
      projects_count:    @counts.projects,
      comments_count:    @counts.comments,
      likes_given_count: @counts.likes_given,
      # Net score: likes received minus dislikes received.
      likes_received_count: @counts.likes_received,
    }
  end
end
