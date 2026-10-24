class AddBuildUsageCounters::V00000000000029 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(Build) do
      # Files count a download, browser builds count a launch. Only the author
      # sees these numbers; they are best-effort counters, not analytics.
      add downloads_count : Int64, default: 0
      add launches_count : Int64, default: 0
    end
  end

  def rollback
    alter table_for(Build) do
      remove :launches_count
      remove :downloads_count
    end
  end
end
