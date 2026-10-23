class ForumAiAnswer < BaseModel
  table do
    belongs_to topic : ForumTopic
    column body : String
    column model : String
    # queued | ready | failed | skipped
    column status : String
    column error : String?
    column prompt_tokens : Int32
    column completion_tokens : Int32
  end

  def ready? : Bool
    status == "ready"
  end
end
