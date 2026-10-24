class ToggleForumPostReaction < Avram::Operation
  needs post : ForumPost
  needs user : User
  needs kind : String

  def run
    AppDatabase.transaction do
      existing = ForumPostReactionQuery.new.for_post(post.id).for_user(user.id).first?

      if existing
        if existing.kind == kind
          ForumPostReaction::DeleteOperation.delete!(existing)
        else
          SaveForumPostReaction.update!(existing, kind: kind)
        end
      else
        SaveForumPostReaction.create!(post_id: post.id, user_id: user.id, kind: kind)
      end
    end
  rescue error : PG::Error
    # Two clicks at once: the unique index keeps one row and the second
    # request settles on whatever was stored first.
    raise error unless ForumPostReactionQuery.new.for_post(post.id).for_user(user.id).first?
  end
end
