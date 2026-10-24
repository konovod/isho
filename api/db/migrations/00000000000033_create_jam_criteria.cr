class CreateJamCriteria::V00000000000033 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(JamCriterion) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to jam : Jam, on_delete: :cascade
      add title : String
      add description : String?
      add weight : Int32, default: 1
      add position : Int32, default: 0
    end
  end

  def rollback
    drop table_for(JamCriterion)
  end
end
