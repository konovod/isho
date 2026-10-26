class ImportJob < BaseModel
  table do
    belongs_to user : User
    belongs_to project : Project?
    column source_url : String
    # queued | running | done | failed | skipped | cancelled
    column status : String
    # fetch | extract | ai | screenshots | done
    column step : String
    column result : String?
    column error : String?
    column attempts : Int32
    column run_after : Time
    column started_at : Time?
    column finished_at : Time?
    column prompt_tokens : Int32
    column completion_tokens : Int32
  end

  def finished? : Bool
    %w[done failed skipped cancelled].includes?(status)
  end
end
