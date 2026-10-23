require "file_utils"

# Removes leftovers that no row points at anymore:
#   * upload sessions older than the TTL,
#   * chunk files without a session,
#   * unpacked builds whose row is gone.
#
#   ./bin/tasks storage.cleanup             # dry run
#   ./bin/tasks storage.cleanup --yes
class Storage::Cleanup < LuckyTask::Task
  summary "Delete expired uploads and orphaned build files"

  switch yes, "Actually delete files and rows (without this flag the task is a dry run)"

  def call
    delete_expired_sessions
    delete_orphan_parts
    delete_orphan_web_dirs
  end

  private def delete_expired_sessions
    cutoff = AppSettings::UPLOAD_SESSION_TTL.ago
    sessions = UploadSessionQuery.new.older_than(cutoff).results

    puts "Expired upload sessions: #{sessions.size}"
    if yes?
      sessions.each { |session| DeleteUploadSession.run!(session: session) }
    end
  end

  private def delete_orphan_parts
    tokens = UploadSessionQuery.new.results.map(&.token).to_set
    parts = Dir.glob("#{UploadFiles::DIRECTORY}/*.part")
    orphans = parts.reject { |path| tokens.includes?(File.basename(path, ".part")) }

    puts "Chunk files without a session: #{orphans.size}"
    if yes?
      orphans.each { |path| File.delete?(path) }
    end
  end

  private def delete_orphan_web_dirs
    known = BuildQuery.new.web.results.map(&.public_id).to_set
    directories = Dir.glob("#{BuildStorage::WEB_DIRECTORY}/*").select do |path|
      File.directory?(path)
    end

    # A build that is being unpacked right now has no row yet; only touch
    # directories that are at least an hour old.
    cutoff = 1.hour.ago
    orphans = directories.select do |path|
      next false if known.includes?(File.basename(path))

      info = File.info?(path)
      info && info.modification_time < cutoff
    end

    puts "Build directories without a row: #{orphans.size}"
    if yes?
      orphans.each { |path| FileUtils.rm_rf(path) }
    end
  end
end
