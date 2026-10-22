# Removes the stress-test data set created by db.stress.seed.
#
#   ./bin/tasks db.stress.cleanup            # dry run: print what would be removed
#   ./bin/tasks db.stress.cleanup --yes      # delete
#   ./bin/tasks db.stress.cleanup --yes --vacuum
#
# Only records with the stress markers are touched. Before deleting users the
# task verifies that they own and wrote nothing outside those markers; if they
# do, it stops instead of cascading into real data.
class Db::Stress::Cleanup < LuckyTask::Task
  summary "Remove the stress-test data set created by db.stress.seed"

  switch yes, "Actually delete the data (without this flag the task is a dry run)"
  switch force, "Delete stray stress posts through DeleteUserContent when safety checks fail"
  switch vacuum, "Run VACUUM (FULL, ANALYZE) on the affected tables after deleting"

  def call
    started = Time.instant
    database_before = Db::Stress::Support.db_size

    users = stress_users
    projects = stress_projects
    tags = stress_tags
    topics = stress_topics
    counts = Db::Stress::Support.stress_counts
    problems = safety_problems

    puts "Stress cleanup"
    puts "  database: #{Db::Stress::Support.format_bytes(database_before)}"
    puts "  records found:"
    Db::Stress::Support.print_marker_counts
    puts "  stray posts by stress users outside stress topics: #{Db::Stress::Support.stray_posts_by_stress_users}"

    unless problems.empty?
      puts ""
      puts "Safety check failed:"
      problems.each { |problem| puts "  - #{problem}" }
      if problems.any? { |problem| !problem.starts_with?("stray posts") }
        puts ""
        puts "Refusing to delete: stress accounts own content outside the markers."
        puts "Move that content to a normal account or remove the markers manually first."
        return
      end

      unless force?
        puts ""
        puts "Re-run with --force to remove the stray posts through DeleteUserContent."
        return
      end
    end

    unless yes?
      puts ""
      puts "Dry run. Re-run with --yes to delete these #{counts.users} users, #{counts.projects} projects, " +
           "#{counts.tags} tags, #{counts.topics} topics and #{counts.posts_in_topics} messages."
      return
    end

    puts ""

    step("screenshots (files)", projects.size) do |progress|
      delete_screenshot_files(projects, progress)
    end

    step("forum topics (messages cascade)", topics.size) do |progress|
      topics.each_with_index do |topic, index|
        ForumTopic::DeleteOperation.delete!(topic)
        progress.call(index + 1, topics.size)
      end
    end

    remaining_posts = if users.empty?
                        0_i64
                      else
                        ForumPostQuery.new.user_id.in(users.map(&.id)).select_count
                      end
    if remaining_posts.positive?
      if force?
        step("stray forum posts", users.size) do |progress|
          users.each_with_index do |user, index|
            if ForumPostQuery.new.user_id(user.id).first?
              DeleteUserContent.run!(user: user)
            end
            progress.call(index + 1, users.size)
          end
        end
      else
        raise "Refusing to delete users: #{remaining_posts} posts by stress users remain outside stress topics"
      end
    end

    step("projects (tags, screenshots, devlogs cascade)", projects.size) do |progress|
      projects.each_with_index do |project, index|
        Project::DeleteOperation.delete!(project)
        progress.call(index + 1, projects.size)
      end
    end

    step("tags", tags.size) do |progress|
      tags.each_with_index do |tag, index|
        unless ProjectTagQuery.new.tag_id(tag.id).first?
          Tag::DeleteOperation.delete!(tag)
        end
        progress.call(index + 1, tags.size)
      end
    end

    step("users", users.size) do |progress|
      users.each_with_index do |user, index|
        User::DeleteOperation.delete!(user)
        progress.call(index + 1, users.size)
      end
    end

    verify_empty!
    database_after = Db::Stress::Support.db_size

    if vacuum?
      puts ""
      puts "Running VACUUM (FULL, ANALYZE)..."
      vacuum_started = Time.instant
      AppDatabase.exec(<<-SQL)
        VACUUM (FULL, ANALYZE)
          users, projects, tags, project_tags, screenshots,
          forum_topics, forum_posts, auth_sessions, devlogs, downloads
        SQL
      database_after = Db::Stress::Support.db_size
      puts "  done in #{Db::Stress::Support.format_seconds((Time.instant - vacuum_started).total_seconds)}"
    end

    elapsed = (Time.instant - started).total_seconds
    puts ""
    puts "Cleanup done in #{Db::Stress::Support.format_seconds(elapsed)}"
    puts "  database: #{Db::Stress::Support.format_bytes(database_before)} -> #{Db::Stress::Support.format_bytes(database_after)}"
    puts "  media:    #{Db::Stress::Support.format_bytes(Db::Stress::Support.media_size)}"
    unless vacuum?
      puts "  tip: --vacuum runs VACUUM (FULL), which reclaims disk but locks the tables"
    end
  end

  private def stress_users : Array(User)
    UserQuery.new
      .username.ilike(Db::Stress::USERNAME_SQL_PATTERN)
      .email.ilike(Db::Stress::EMAIL_SQL_PATTERN)
      .results
  end

  private def stress_projects : Array(Project)
    ProjectQuery.new
      .slug.ilike(Db::Stress::PROJECT_SQL_PATTERN)
      .preload_screenshots
      .results
  end

  private def stress_tags : Array(Tag)
    TagQuery.new.slug.ilike(Db::Stress::TAG_SQL_PATTERN).results
  end

  private def stress_topics : Array(ForumTopic)
    ForumTopicQuery.new.slug.ilike(Db::Stress::TOPIC_SQL_PATTERN).results
  end

  private def safety_problems : Array(String)
    problems = [] of String

    if count = Db::Stress::Support.non_marker_projects_for_stress_users
      problems << "#{count} projects of stress users do not have the project marker" if count.positive?
    end
    if count = Db::Stress::Support.non_marker_topics_for_stress_users
      problems << "#{count} forum topics of stress users do not have the topic marker" if count.positive?
    end
    if count = Db::Stress::Support.stray_posts_by_stress_users
      problems << "stray posts: #{count} posts by stress users are outside stress topics" if count.positive?
    end

    problems
  end

  private def delete_screenshot_files(projects : Array(Project), progress : Proc(Int32, Int32, Nil)) : Nil
    projects.each_with_index do |project, index|
      project.screenshots.each do |screenshot|
        screenshot.image.try(&.delete)
      end
      progress.call(index + 1, projects.size)
    end
  end

  private def step(label : String, total : Int32, &) : Nil
    started = Time.instant
    progress = ->(done : Int32, count : Int32) do
      if (done % 100).zero? || done == count
        puts "  #{label}: #{done}/#{count}"
      end
    end

    yield progress
    elapsed = (Time.instant - started).total_seconds
    puts "  #{label}: #{total} in #{Db::Stress::Support.format_seconds(elapsed)}"
  end

  private def verify_empty! : Nil
    counts = Db::Stress::Support.stress_counts

    checks = {
      "users"        => counts.users,
      "projects"     => counts.projects,
      "tags"         => counts.tags,
      "project tags" => counts.project_tags,
      "screenshots"  => counts.screenshots,
      "topics"       => counts.topics,
      "posts"        => counts.posts_in_topics,
    }

    left = checks.select { |_, value| value.positive? }
    unless left.empty?
      raise "Stress markers still present: #{left.inspect}"
    end

    posts_by_users = Db::Stress::Support.stress_counts.posts_by_users
    raise "Stress users still have #{posts_by_users} posts" if posts_by_users.positive?
  end
end
