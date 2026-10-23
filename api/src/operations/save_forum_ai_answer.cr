class SaveForumAiAnswer < ForumAiAnswer::SaveOperation
  permit_columns body, model, status, error, prompt_tokens, completion_tokens
end
