# Counts everything the storage limits apply to.
#
# Builds and in-flight upload sessions have an explicit size column. Images
# (screenshots and Markdown pictures) keep the size Latch recorded in their
# JSON metadata, so the sum is exact for the original files; the resized
# variants are a small extra that the disk reserve covers.
module StorageUsage
  record UserUsage, builds : Int64, sessions : Int64, images : Int64 do
    def total : Int64
      builds + sessions + images
    end
  end

  record ProjectUsage, builds : Int64, sessions : Int64 do
    def total : Int64
      builds + sessions
    end
  end

  record ProjectTotal, slug : String, title : String, used_bytes : Int64

  def self.for_user(user_id : Int64) : UserUsage
    AppDatabase.run do |db|
      builds, sessions, images = db.query_one(SQL_USER, user_id, as: {Int64, Int64, Int64})
      UserUsage.new(builds, sessions, images)
    end
  end

  def self.for_project(project_id : Int64) : ProjectUsage
    AppDatabase.run do |db|
      builds, sessions = db.query_one(SQL_PROJECT, project_id, as: {Int64, Int64})
      ProjectUsage.new(builds, sessions)
    end
  end

  def self.server_total : Int64
    AppDatabase.run do |db|
      db.query_one(SQL_SERVER, as: Int64)
    end
  end

  def self.per_project(user_id : Int64) : Array(ProjectTotal)
    AppDatabase.run do |db|
      db.query_all(SQL_PROJECTS, user_id, as: {String, String, Int64}).map do |(slug, title, used)|
        ProjectTotal.new(slug, title, used)
      end
    end
  end

  def self.fits_account?(user_id : Int64, bytes : Int64) : Bool
    for_user(user_id).total + bytes <= AppSettings.account_storage_limit
  end

  def self.fits_server?(bytes : Int64) : Bool
    server_total + bytes <= AppSettings.server_storage_limit
  end

  private SQL_USER = <<-SQL
    SELECT
      COALESCE((
        SELECT SUM(b.size_bytes)
        FROM builds b
        JOIN projects p ON p.id = b.project_id
        WHERE p.user_id = $1
      ), 0)::bigint AS builds,
      COALESCE((
        SELECT SUM(s.total_bytes)
        FROM upload_sessions s
        WHERE s.user_id = $1
      ), 0)::bigint AS sessions,
      (
        COALESCE((
          SELECT SUM(COALESCE((sc.image->'metadata'->>'size')::bigint, 0))
          FROM screenshots sc
          JOIN projects p ON p.id = sc.project_id
          WHERE p.user_id = $1
        ), 0)
        + COALESCE((
          SELECT SUM(COALESCE((mi.image->'metadata'->>'size')::bigint, 0))
          FROM markdown_images mi
          WHERE mi.user_id = $1
        ), 0)
        + COALESCE((
          SELECT SUM(COALESCE((j.banner->'metadata'->>'size')::bigint, 0))
          FROM jams j
          WHERE j.user_id = $1
        ), 0)
      )::bigint AS images
    SQL

  private SQL_PROJECT = <<-SQL
    SELECT
      COALESCE((
        SELECT SUM(b.size_bytes)
        FROM builds b
        WHERE b.project_id = $1
      ), 0)::bigint AS builds,
      COALESCE((
        SELECT SUM(s.total_bytes)
        FROM upload_sessions s
        WHERE s.project_id = $1
      ), 0)::bigint AS sessions
    SQL

  private SQL_SERVER = <<-SQL
    SELECT (
      COALESCE((SELECT SUM(size_bytes) FROM builds), 0)
      + COALESCE((SELECT SUM(total_bytes) FROM upload_sessions), 0)
      + COALESCE((SELECT SUM(COALESCE((image->'metadata'->>'size')::bigint, 0)) FROM screenshots), 0)
      + COALESCE((SELECT SUM(COALESCE((image->'metadata'->>'size')::bigint, 0)) FROM markdown_images), 0)
      + COALESCE((SELECT SUM(COALESCE((banner->'metadata'->>'size')::bigint, 0)) FROM jams), 0)
    )::bigint
    SQL

  private SQL_PROJECTS = <<-SQL
    SELECT p.slug, p.title,
      (COALESCE(b.bytes, 0) + COALESCE(s.bytes, 0))::bigint AS used
    FROM projects p
    LEFT JOIN (
      SELECT project_id, SUM(size_bytes) AS bytes FROM builds GROUP BY project_id
    ) b ON b.project_id = p.id
    LEFT JOIN (
      SELECT project_id, SUM(total_bytes) AS bytes FROM upload_sessions GROUP BY project_id
    ) s ON s.project_id = p.id
    WHERE p.user_id = $1
    ORDER BY p.created_at DESC
    SQL
end
