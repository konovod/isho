class JamCriterion < BaseModel
  table do
    belongs_to jam : Jam
    column title : String
    column description : String?
    column weight : Int32
    column position : Int32
    has_many scores : JamScore
  end
end
