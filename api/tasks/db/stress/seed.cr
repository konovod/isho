# Creates the stress-test data set. Run it from the api directory:
#
#   ./bin/tasks db.stress.seed
#   ./bin/tasks db.stress.seed --users=100 --projects=100 --tags=100 --topics=10 --posts-per-topic=20
#
# Every record gets a marker (stresstest_* usernames, stress-* slugs), so
# db.stress.cleanup can remove it without touching real data. The task is
# idempotent: a repeated run finds existing records and adds only what is
# missing, which also makes an interrupted run resumable.
class Db::Stress::Seed < LuckyTask::Task
  summary "Create users, projects, tags, forum topics and posts for the stress test"

  int32 :users, "Number of users", default: 1000
  int32 :projects, "Number of projects", default: 1000
  int32 :tags, "Number of tags", default: 1000
  int32 :topics, "Number of forum topics", default: 1000
  int32 :posts_per_topic, "Messages per topic, including the opening post", default: 200
  int32 :screenshots, "Screenshots per project (0 disables ImageMagick processing)", default: 1

  @source_image : String? = nil
  @posts_created = 0
  @sample_project_path : String? = nil
  @sample_topic_path : String? = nil

  def call
    started = Time.instant
    validate_options!

    Db::Seed::ForumSections.ensure_all
    sections = ForumSectionQuery.new.ordered.results
    projects_section = sections.find { |section| section.slug == "projects" }
    general_sections = sections.reject { |section| section.slug == "projects" }

    if @topics > 0 && projects_section.nil?
      raise "Forum section 'projects' is missing. Run db.seed.required_data first."
    end
    if @topics > 0 && general_sections.empty?
      raise "There are no general forum sections. Run db.seed.required_data first."
    end
    if @screenshots > 0
      Db::Stress::Support.ensure_imagemagick!
    end

    database_before = Db::Stress::Support.db_size
    puts "Stress seed"
    puts "  users: #{@users}, projects: #{@projects}, tags: #{@tags}"
    puts "  topics: #{@topics}, messages per topic: #{@posts_per_topic}"
    puts "  screenshots per project: #{@screenshots}"
    puts "  database before: #{Db::Stress::Support.format_bytes(database_before)}"
    puts ""

    users = seed_users
    puts ""

    tags = seed_tags
    puts ""

    projects = seed_projects(users, tags)
    puts ""

    seed_topics(users, projects, projects_section, general_sections)
    puts ""

    database_after = Db::Stress::Support.db_size
    media_size = Db::Stress::Support.media_size
    elapsed = (Time.instant - started).total_seconds
    counts = Db::Stress::Support.stress_counts

    puts "Done in #{Db::Stress::Support.format_seconds(elapsed)}"
    puts "  database: #{Db::Stress::Support.format_bytes(database_before)} -> #{Db::Stress::Support.format_bytes(database_after)} (+#{Db::Stress::Support.format_bytes(database_after - database_before)})"
    puts "  media:    #{Db::Stress::Support.format_bytes(media_size)}"
    puts "  records:"
    Db::Stress::Support.print_marker_counts
    puts "  password for all stress accounts: #{Db::Stress::PASSWORD}"
    puts ""
    puts "  sample project: #{@sample_project_path || "/p/#{Db::Stress::Support.project_slug(1)}"}"
    puts "  sample topic:   #{@sample_topic_path || "(none)"}"
    puts "  sample user:    /u/#{Db::Stress::Support.username(1)}"
  ensure
    @source_image.try { |path| File.delete?(path) }
  end

  private def validate_options! : Nil
    raise "--users must be at least 1" if @users < 1
    raise "--projects cannot be negative" if @projects < 0
    raise "--tags cannot be negative" if @tags < 0
    raise "--topics cannot be negative" if @topics < 0
    raise "--posts-per-topic must be at least 1" if @posts_per_topic < 1
    raise "--posts-per-topic must be 1000 or less" if @posts_per_topic > 1000
    unless 0 <= @screenshots <= AppSettings::MAX_SCREENSHOTS
      raise "--screenshots must be between 0 and #{AppSettings::MAX_SCREENSHOTS}"
    end
  end

  private def seed_users : Array(User)
    started = Time.instant
    password_hash = Authentic.generate_encrypted_password(Db::Stress::PASSWORD)
    users = Array(User).new(@users)
    created = 0

    1.upto(@users) do |index|
      username = Db::Stress::Support.username(index)
      user = UserQuery.new.username(username).first?

      unless user
        user = User::SaveOperation.create!(
          email: Db::Stress::Support.email(index),
          username: username,
          display_name: "Стресс-автор #{index}",
          bio: "Автоматически созданный аккаунт для нагрузочного теста №#{index}.",
          encrypted_password: password_hash,
          is_admin: false,
          theme: "dark",
          email_confirmed_at: Time.utc,
        )
        created += 1
      end

      users << user
      log_progress("users", index, @users, started) if (index % 100).zero? || index == @users
    end

    puts "Users: #{users.size} (#{created} created) — #{Db::Stress::Support.format_seconds((Time.instant - started).total_seconds)}"
    users
  end

  private def seed_tags : Array(Tag)
    started = Time.instant
    tags = Array(Tag).new(@tags)
    created = 0

    1.upto(@tags) do |index|
      slug = Db::Stress::Support.tag_slug(index)
      unless slug.starts_with?(Db::Stress::TAG_SLUG_PREFIX)
        raise "Unexpected tag slug #{slug.inspect}; the cleanup marker would not match"
      end

      tag = TagQuery.new.slug(slug).first?

      unless tag
        tag = SaveTag.create!(name: Db::Stress::Support.tag_name(index))
        created += 1
      end

      tags << tag
      log_progress("tags", index, @tags, started) if (index % 100).zero? || index == @tags
    end

    puts "Tags: #{tags.size} (#{created} created) — #{Db::Stress::Support.format_seconds((Time.instant - started).total_seconds)}"
    tags
  end

  private def seed_projects(users : Array(User), tags : Array(Tag)) : Array(Project)
    started = Time.instant
    projects = Array(Project).new(@projects)
    created = 0

    1.upto(@projects) do |index|
      slug = Db::Stress::Support.project_slug(index)
      project = ProjectQuery.new.slug(slug).first?

      unless project
        kind = Db::Stress::KINDS[index % Db::Stress::KINDS.size]
        project = SaveProject.create!(
          title: Db::Stress::Support.project_title(index),
          slug: slug,
          tagline: Db::Stress::Support.tagline(index),
          description: Db::Stress::Support.project_description(index),
          kind: kind,
          dev_status: Db::Stress::DEV_STATUSES[index % Db::Stress::DEV_STATUSES.size],
          genre: kind == "game" ? Db::Stress::GENRES[index % Db::Stress::GENRES.size] : nil,
          user_id: users[(index - 1) % users.size].id,
          status: "published",
          published_at: Db::Stress::Support.project_published_at(index),
          created_at: Db::Stress::Support.project_published_at(index) - 1.day,
        )
        created += 1
      end

      @sample_project_path ||= "/p/#{project.slug}"

      ensure_project_tags(project, index, tags)
      ensure_screenshots(project, index)
      projects << project

      if (index % 50).zero? || index == @projects
        log_progress("projects", index, @projects, started)
      end
    end

    puts "Projects: #{projects.size} (#{created} created) — #{Db::Stress::Support.format_seconds((Time.instant - started).total_seconds)}"
    projects
  end

  private def ensure_project_tags(project : Project, index : Int32, tags : Array(Tag)) : Nil
    return if tags.empty?

    existing = ProjectTagQuery.new.project_id(project.id).results.map(&.tag_id)
    wanted = Math.min(4, tags.size)

    wanted.times do |offset|
      tag = tags[(index * 4 + offset) % tags.size]
      next if existing.includes?(tag.id)

      ProjectTag::SaveOperation.create!(project_id: project.id, tag_id: tag.id)
    end
  end

  private def ensure_screenshots(project : Project, index : Int32) : Nil
    return if @screenshots <= 0

    existing = ScreenshotQuery.new.project_id(project.id).select_count.to_i
    return if existing >= @screenshots

    source = source_image
    (existing...@screenshots).each do |position|
      upload = Db::Stress::Support.build_upload(
        source,
        "stress-#{project.id}-#{position + 1}.jpg",
        "image/jpeg",
      )

      begin
        SaveScreenshot.create!(
          image_file: upload,
          project_id: project.id,
          caption: "Скриншот #{position + 1} проекта #{Db::Stress::Support.padded(index)}",
          position: position,
          is_cover: position.zero?,
        )
      ensure
        File.delete?(upload.tempfile.path)
      end
    end
  end

  private def source_image : String
    @source_image ||= Db::Stress::Support.generate_source_image
  end

  private def seed_topics(
    users : Array(User),
    projects : Array(Project),
    projects_section : ForumSection?,
    general_sections : Array(ForumSection),
  ) : Nil
    started = Time.instant
    created = 0
    @posts_created = 0
    sections_by_id = {} of Int64 => ForumSection
    general_sections.each { |item| sections_by_id[item.id] = item }
    projects_section.try { |item| sections_by_id[item.id] = item }

    1.upto(@topics) do |index|
      section, project = topic_target(index, projects, projects_section, general_sections)
      slug = Db::Stress::Support.topic_slug(index)
      started_at = Db::Stress::Support.topic_started_at(index)

      # Slugs are unique globally in this data set. Looking the topic up by
      # slug (not by section) keeps a resumed run working even when the topic
      # distribution options change.
      topic = ForumTopicQuery.new.slug(slug).first?

      unless topic
        topic = SaveForumTopic.create!(
          section_id: section.id,
          user_id: users[(index - 1) % users.size].id,
          project_id: project.try(&.id),
          title: Db::Stress::Support.topic_title(index),
          slug: slug,
          replies_count: 0,
          last_post_at: started_at,
          last_post_user_id: users[(index - 1) % users.size].id,
          created_at: started_at,
          updated_at: started_at,
        )
        created += 1
      end

      actual_section = sections_by_id[topic.section_id]? || section
      @sample_topic_path ||= "/forum/#{actual_section.slug}/#{topic.slug}"
      ensure_topic_posts(topic, index, users)

      if (index % 10).zero? || index == @topics
        elapsed = (Time.instant - started).total_seconds
        rate = elapsed.positive? ? (@posts_created / elapsed).round(0) : 0
        puts "  topics #{index}/#{@topics}, new posts #{@posts_created}, #{rate} posts/s, #{Db::Stress::Support.format_seconds(elapsed)}"
      end
    end

    puts "Topics: #{@topics} (#{created} created), posts created now: #{@posts_created} — #{Db::Stress::Support.format_seconds((Time.instant - started).total_seconds)}"
  end

  private def topic_target(
    index : Int32,
    projects : Array(Project),
    projects_section : ForumSection?,
    general_sections : Array(ForumSection),
  ) : {ForumSection, Project?}
    if projects.any? && projects_section && index.odd?
      {projects_section.not_nil!, projects[(index - 1) % projects.size]}
    else
      section = general_sections[(index // 2) % general_sections.size]
      {section, nil}
    end
  end

  private def ensure_topic_posts(topic : ForumTopic, index : Int32, users : Array(User)) : Nil
    existing = ForumPostQuery.new.for_topic(topic.id).select_count.to_i
    ensure_first_post_author(topic, index, users)
    return if existing >= @posts_per_topic

    started_at = Db::Stress::Support.topic_started_at(index)
    previous_id = ForumPostQuery.new.for_topic(topic.id).newest_first.first?.try(&.id)
    last_post_at = topic.last_post_at
    last_post_user_id = topic.last_post_user_id

    AppDatabase.transaction do
      (existing...@posts_per_topic).each do |post_index|
        author = if post_index.zero?
                   users[(index - 1) % users.size]
                 else
                   users[(index * 7 + post_index) % users.size]
                 end
        created_at = Db::Stress::Support.post_created_at(started_at, post_index)
        quoted_post_id = if post_index.positive? && (post_index % 17).zero?
                           previous_id
                         end

        post = SaveForumPost.create!(
          topic_id: topic.id,
          user_id: author.id,
          body: Db::Stress::Support.post_body(index, post_index),
          quoted_post_id: quoted_post_id,
          created_at: created_at,
          updated_at: created_at,
        )

        previous_id = post.id
        last_post_at = created_at
        last_post_user_id = author.id
        @posts_created += 1
      end

      ForumTopic::SaveOperation.update!(
        topic,
        replies_count: (@posts_per_topic - 1).to_i32,
        last_post_at: last_post_at,
        last_post_user_id: last_post_user_id,
      )
    end
  end

  # The opening post must belong to the topic author, like CreateForumTopic
  # does. This also repairs data created by an older version of this task.
  private def ensure_first_post_author(topic : ForumTopic, index : Int32, users : Array(User)) : Nil
    expected_author = users[(index - 1) % users.size]
    first_post = ForumPostQuery.new.for_topic(topic.id).chronological.first?
    if first_post && first_post.user_id != expected_author.id
      ForumPost::SaveOperation.update!(first_post, user_id: expected_author.id)
    end
  end

  private def log_progress(label : String, done : Int32, total : Int32, started : Time::Instant) : Nil
    elapsed = (Time.instant - started).total_seconds
    rate = done / [elapsed, 0.001].max
    remaining = total - done
    eta = rate.positive? ? (remaining / rate) : 0.0
    puts "  #{label} #{done}/#{total}, #{rate.round(1)}/s, ETA #{Db::Stress::Support.format_seconds(eta)}"
  end
end
