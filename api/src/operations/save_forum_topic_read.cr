class SaveForumTopicRead < ForumTopicRead::SaveOperation
  permit_columns read_count
end
