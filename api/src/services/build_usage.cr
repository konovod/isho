# Counters for hosted builds: a file build being downloaded and a browser build
# being launched. They are best-effort numbers shown to the author only, so a
# request that does not match a build simply updates nothing.
#
# The increment is one atomic SQL statement: reading a model and saving it would
# turn parallel downloads into a lost update.
module BuildUsage
  def self.download(public_id : String, stored_id : String) : Nil
    AppDatabase.run do |db|
      db.exec(SQL_DOWNLOAD, public_id, stored_id)
    end
  end

  def self.launch(public_id : String, entry_path : String) : Nil
    AppDatabase.run do |db|
      db.exec(SQL_LAUNCH, public_id, entry_path)
    end
  end

  private SQL_DOWNLOAD = <<-SQL
    UPDATE builds
    SET downloads_count = downloads_count + 1
    WHERE public_id = $1 AND kind = 'file' AND stored_file->>'id' = $2
    SQL

  private SQL_LAUNCH = <<-SQL
    UPDATE builds
    SET launches_count = launches_count + 1
    WHERE public_id = $1 AND kind = 'web' AND entry_path = $2
    SQL
end
