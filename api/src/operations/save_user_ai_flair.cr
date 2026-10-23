class SaveUserAiFlair < User::SaveOperation
  permit_columns ai_flair, ai_flair_at
end
