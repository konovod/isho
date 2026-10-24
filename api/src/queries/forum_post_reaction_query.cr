class ForumPostReactionQuery < ForumPostReaction::BaseQuery
  def for_post(post_id : Int64)
    post_id(post_id)
  end

  def for_user(user_id : Int64)
    user_id(user_id)
  end

  def by_kind(kind : String)
    kind(kind)
  end

  def newest_first
    created_at.desc_order
  end
end
