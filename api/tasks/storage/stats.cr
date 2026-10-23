# Shows how full the storage is: the server total, the free space that the
# reserve protects, and the accounts that use the most.
#
#   ./bin/tasks storage.stats
class Storage::Stats < LuckyTask::Task
  summary "Show storage usage against the configured limits"

  def call
    server_used = StorageUsage.server_total
    free = DiskSpace.available_bytes

    puts "Server limit:  #{human(AppSettings.server_storage_limit)}"
    puts "Used:          #{human(server_used)}"
    puts "Reserve:       #{human(AppSettings.storage_reserve)} (never used by uploads)"
    if free
      puts "Free space:    #{human(free)} (usable after reserve: #{human(free - AppSettings.storage_reserve)})"
    else
      puts "Free space:    unknown on this platform"
    end
    puts "Project limit: #{human(AppSettings.project_storage_limit)}"
    puts "Account limit: #{human(AppSettings.account_storage_limit)}"
    puts ""

    rows = AppDatabase.run do |db|
      db.query_all(SQL, as: {String, Int64})
    end

    if rows.empty?
      puts "No accounts yet."
      return
    end

    puts "Top accounts:"
    rows.each do |(username, used)|
      puts "  #{username.ljust(24)} #{human(used).rjust(10)}"
    end
  end

  private SQL = <<-SQL
    SELECT u.username,
      (
        COALESCE(b.bytes, 0) + COALESCE(s.bytes, 0)
        + COALESCE(sc.bytes, 0) + COALESCE(mi.bytes, 0)
      )::bigint AS used
    FROM users u
    LEFT JOIN (
      SELECT p.user_id, SUM(b.size_bytes) AS bytes
      FROM builds b JOIN projects p ON p.id = b.project_id
      GROUP BY p.user_id
    ) b ON b.user_id = u.id
    LEFT JOIN (
      SELECT user_id, SUM(total_bytes) AS bytes FROM upload_sessions GROUP BY user_id
    ) s ON s.user_id = u.id
    LEFT JOIN (
      SELECT p.user_id, SUM(COALESCE((sc.image->'metadata'->>'size')::bigint, 0)) AS bytes
      FROM screenshots sc JOIN projects p ON p.id = sc.project_id
      GROUP BY p.user_id
    ) sc ON sc.user_id = u.id
    LEFT JOIN (
      SELECT user_id, SUM(COALESCE((mi.image->'metadata'->>'size')::bigint, 0)) AS bytes
      FROM markdown_images mi GROUP BY user_id
    ) mi ON mi.user_id = u.id
    ORDER BY used DESC
    LIMIT 20
    SQL

  private def human(bytes : Int64) : String
    kb = bytes / 1_000.0
    return "#{(bytes / 1000.0).round(1)} KB" if kb < 1_000

    mb = kb / 1_000
    if mb < 1_000
      "#{mb.round(1)} MB"
    else
      "#{(mb / 1_000).round(2)} GB"
    end
  end
end
