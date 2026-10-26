class SaveForumTopicRead < ForumTopicRead::SaveOperation
  permit_columns read_count, last_post_id
end
