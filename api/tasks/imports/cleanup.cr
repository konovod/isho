# Removes finished import jobs past the retention window and gives up on jobs
# that never started. Called from the worker once a day; safe to run by hand.
class Import::CleanupTask < LuckyTask::Task
  name "imports.cleanup"
  summary "Delete old import jobs"

  def call
    removed = Import::Jobs.cleanup(Time.utc - AppSettings::IMPORT_RETENTION)
    stale = Import::Jobs.abandon_stale(Time.utc - 1.day)

    puts "Removed #{removed} old jobs, abandoned #{stale} stale jobs"
  end
end
