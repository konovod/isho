# Prints row counts, database size and index sizes for the stress test.
#
#   ./bin/tasks db.stress.stats
#   ./bin/tasks db.stress.stats --json
class Db::Stress::Stats < LuckyTask::Task
  summary "Show database and stress-data statistics"

  switch json, "Print machine-readable JSON instead of a table"

  def call
    counts = Db::Stress::Support.row_counts
    stress = Db::Stress::Support.stress_counts
    tables = Db::Stress::Support.table_sizes
    indexes = Db::Stress::Support.top_indexes
    database_size = Db::Stress::Support.db_size
    media_size = Db::Stress::Support.media_size

    if json?
      puts build_json(database_size, media_size, counts, stress, tables, indexes)
      return
    end

    puts "Database: #{Db::Stress::Support.format_bytes(database_size)}"
    puts "Media:    #{Db::Stress::Support.format_bytes(media_size)}"
    puts ""
    puts "Rows"
    puts "  users:          #{counts.users}"
    puts "  projects:       #{counts.projects}"
    puts "  tags:           #{counts.tags}"
    puts "  project_tags:   #{counts.project_tags}"
    puts "  screenshots:    #{counts.screenshots}"
    puts "  forum_sections: #{counts.forum_sections}"
    puts "  forum_topics:   #{counts.forum_topics}"
    puts "  forum_posts:    #{counts.forum_posts}"
    puts "  auth_sessions:  #{counts.auth_sessions}"
    puts ""
    puts "Stress markers"
    puts "  users:       #{stress.users}"
    puts "  projects:    #{stress.projects}"
    puts "  tags:        #{stress.tags}"
    puts "  project tags:#{stress.project_tags}"
    puts "  screenshots: #{stress.screenshots}"
    puts "  topics:      #{stress.topics}"
    puts "  posts:       #{stress.posts_in_topics}"
    puts ""
    puts "Tables"
    puts "  #{pad("name", 18)} #{pad("total", 10)} #{pad("heap", 10)} #{pad("indexes", 10)} #{pad("toast", 10)}"
    tables.each do |table|
      puts "  #{pad(table.name, 18)} #{pad(Db::Stress::Support.format_bytes(table.total), 10)} #{pad(Db::Stress::Support.format_bytes(table.heap), 10)} #{pad(Db::Stress::Support.format_bytes(table.indexes), 10)} #{pad(Db::Stress::Support.format_bytes(table.toast), 10)}"
    end
    puts ""
    puts "Top indexes"
    indexes.each do |index|
      puts "  #{pad(Db::Stress::Support.format_bytes(index.bytes), 10)} #{index.name}"
    end
  end

  private def pad(value : String, width : Int32) : String
    value.ljust(width)
  end

  private def build_json(
    database_size : Int64,
    media_size : Int64,
    counts : Db::Stress::Support::RowCounts,
    stress : Db::Stress::Support::StressCounts,
    tables : Array(Db::Stress::Support::TableSize),
    indexes : Array(Db::Stress::Support::IndexSize),
  ) : String
    JSON.build do |json|
      json.object do
        json.field "database_size", database_size
        json.field "media_size", media_size
        json.field "counts" do
          json.object do
            json.field "users", counts.users
            json.field "projects", counts.projects
            json.field "tags", counts.tags
            json.field "project_tags", counts.project_tags
            json.field "screenshots", counts.screenshots
            json.field "forum_sections", counts.forum_sections
            json.field "forum_topics", counts.forum_topics
            json.field "forum_posts", counts.forum_posts
            json.field "auth_sessions", counts.auth_sessions
          end
        end
        json.field "stress" do
          json.object do
            json.field "users", stress.users
            json.field "projects", stress.projects
            json.field "tags", stress.tags
            json.field "project_tags", stress.project_tags
            json.field "screenshots", stress.screenshots
            json.field "topics", stress.topics
            json.field "posts", stress.posts_in_topics
          end
        end
        json.field "tables" do
          json.array do
            tables.each do |table|
              json.object do
                json.field "name", table.name
                json.field "total", table.total
                json.field "heap", table.heap
                json.field "indexes", table.indexes
                json.field "toast", table.toast
              end
            end
          end
        end
        json.field "top_indexes" do
          json.array do
            indexes.each do |index|
              json.object do
                json.field "name", index.name
                json.field "bytes", index.bytes
              end
            end
          end
        end
      end
    end
  end
end
