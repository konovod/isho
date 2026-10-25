record JamScoreInput, criterion_id : Int64, score : Int32, comment : String?

# Replaces the whole scorecard: a voter can change their scores until the
# judging window closes, but never leaves a half-filled card behind.
class SaveJamScorecard < Avram::Operation
  needs entry : JamEntry
  needs user : User
  needs values : Array(JamScoreInput)

  def run
    AppDatabase.transaction do
      JamScoreQuery.new.for_entry(entry.id).for_user(user.id).results.each do |score|
        JamScore::DeleteOperation.delete!(score)
      end

      values.each do |value|
        JamScore::SaveOperation.create!(
          entry_id: entry.id,
          user_id: user.id,
          criterion_id: value.criterion_id,
          score: value.score,
          comment: value.comment,
        )
      end
    end
  end
end
