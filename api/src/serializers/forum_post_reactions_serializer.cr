class ForumPostReactionsSerializer < BaseSerializer
  def initialize(@summary : ForumReactions::Summary)
  end

  def render
    {
      likes_count:    @summary.likes,
      dislikes_count: @summary.dislikes,
      my_reaction:    @summary.my_reaction,
    }
  end
end
