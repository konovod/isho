class Download < BaseModel
  table do
    belongs_to project : Project
    column label : String
    column url : String
    column platform : String?
    column version : String?
  end
end
