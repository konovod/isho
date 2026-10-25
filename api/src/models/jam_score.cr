class JamScore < BaseModel
  table do
    belongs_to entry : JamEntry
    belongs_to user : User
    belongs_to criterion : JamCriterion
    column score : Int32
    column comment : String?
  end
end
