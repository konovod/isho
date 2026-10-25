class CreateJamScores::V00000000000035 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(JamScore) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to entry : JamEntry, on_delete: :cascade
      add_belongs_to user : User, on_delete: :cascade
      add_belongs_to criterion : JamCriterion, on_delete: :cascade
      add score : Int32
      add comment : String?
    end

    # One scorecard per voter and entry: a row per criterion.
    create_index table_for(JamScore), [:entry_id, :user_id, :criterion_id], unique: true
  end

  def rollback
    drop table_for(JamScore)
  end
end
