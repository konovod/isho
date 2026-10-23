class AiJob < BaseModel
  table do
    # forum_answer | flair
    column kind : String
    belongs_to user : User
    belongs_to topic : ForumTopic?
    # queued | running | done | failed | skipped
    column status : String
    column attempts : Int32
    column run_after : Time
    column started_at : Time?
    column finished_at : Time?
    column error : String?
    column prompt_tokens : Int32
    column completion_tokens : Int32
  end
end
