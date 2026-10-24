class JamCriterionFactory < Avram::Factory
  def initialize
    number = sequence("test-jam-criterion")
    title "Criterion #{number}"
    description "What this criterion measures"
    weight 1
    position 0
    jam_id JamFactory.create.id
  end
end
