class JamEntry < BaseModel
  table do
    belongs_to jam : Jam
    belongs_to project : Project
    belongs_to user : User
    column status : String
    column disqualified_reason : String?
    column disqualified_at : Time?
    belongs_to disqualified_by : User?
    has_many scores : JamScore
  end

  def submitted? : Bool
    status == "submitted"
  end

  def disqualified? : Bool
    status == "disqualified"
  end
end
