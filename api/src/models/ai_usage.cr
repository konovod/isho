class AiUsage < BaseModel
  table do
    belongs_to user : User
    column kind : String
    # Midnight UTC, so limits reset at the same moment on every server.
    column day : Time
    column used : Int32
  end
end
