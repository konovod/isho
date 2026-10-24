class SaveForumPostReaction < ForumPostReaction::SaveOperation
  permit_columns kind
end
