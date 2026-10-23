class CreateAiUsage::V00000000000026 < Avram::Migrator::Migration::V1
  def migrate
    # Per-user daily counters for AI features that a person can trigger. The
    # worker takes a row lock on the counter, so two quick requests cannot
    # both pass the limit.
    create table_for(AiUsage) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to user : User, on_delete: :cascade
      add kind : String
      # Midnight UTC of the day, so limits reset at the same moment everywhere.
      add day : Time
      add used : Int32, default: 0
    end

    create_index table_for(AiUsage), [:user_id, :kind, :day], unique: true
  end

  def rollback
    drop table_for(AiUsage)
  end
end
