require "json"

# Helpers shared by the stress-test tasks (db.stress.*).
#
# The tasks write through Avram operations, like the application does. SQL is
# used directly only for read-only statistics and VACUUM.
module Db::Stress
  USERNAME_PREFIX     = "stresstest"
  EMAIL_DOMAIN        = "stress.isho.local"
  PROJECT_SLUG_PREFIX = "stress-project-"
  TAG_SLUG_PREFIX     = "stress-teg-"
  TOPIC_SLUG_PREFIX   = "stress-topic-"
  PASSWORD            = "stress1234"

  USERNAME_SQL_PATTERN = "stresstest%"
  EMAIL_SQL_PATTERN    = "%@stress.isho.local"
  PROJECT_SQL_PATTERN  = "stress-project-%"
  TAG_SQL_PATTERN      = "stress-teg-%"
  TOPIC_SQL_PATTERN    = "stress-topic-%"

  KINDS        = %w[game tool asset]
  DEV_STATUSES = AppSettings::PROJECT_DEV_STATUSES
  GENRES       = AppSettings::PROJECT_GENRES

  module Support
    record RowCounts,
      users : Int64,
      projects : Int64,
      tags : Int64,
      project_tags : Int64,
      screenshots : Int64,
      forum_sections : Int64,
      forum_topics : Int64,
      forum_posts : Int64,
      auth_sessions : Int64

    record StressCounts,
      users : Int64,
      projects : Int64,
      tags : Int64,
      project_tags : Int64,
      screenshots : Int64,
      topics : Int64,
      posts_in_topics : Int64,
      posts_by_users : Int64

    record TableSize,
      name : String,
      total : Int64,
      heap : Int64,
      indexes : Int64,
      toast : Int64

    record IndexSize,
      name : String,
      bytes : Int64

    # Matches dev-api.ps1: Scoop's ImageMagick does not register its config
    # paths on Windows, so set them before Latch starts calling magick.
    def self.ensure_imagemagick! : Nil
      return if find_magick

      if home = ENV["USERPROFILE"]?
        dir = File.join(home, "scoop", "apps", "imagemagick", "current")
        if File.exists?(File.join(dir, "magick.exe"))
          ENV["MAGICK_HOME"] = dir
          ENV["MAGICK_CONFIGURE_PATH"] = dir
          ENV["MAGICK_CODER_MODULE_PATH"] = File.join(dir, "modules", "coders")
          ENV["PATH"] = "#{dir};#{ENV["PATH"]?}"
          return if find_magick
        end
      end

      raise <<-ERROR
      ImageMagick not found: install it or pass --screenshots=0.
      On Windows the tasks look for %USERPROFILE%\\scoop\\apps\\imagemagick\\current.
      ERROR
    end

    def self.find_magick : String?
      Process.find_executable("magick") || Process.find_executable("convert")
    end

    # Generates one source JPEG in the OS temp directory. Latch copies and
    # resizes it for every project, so a single file is enough.
    def self.generate_source_image : String
      ensure_imagemagick!
      file = File.tempfile("isho-stress-source", ".jpg")
      path = file.path
      file.close

      exe = Process.find_executable("magick") ? "magick" : "convert"
      status = Process.run(
        exe,
        [
          "-size", "1600x900",
          "-seed", "42",
          "plasma:fractal",
          "-quality", "82",
          path,
        ],
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit,
      )
      raise "ImageMagick failed with exit code #{status.exit_code}" unless status.success?

      path
    end

    # Wraps a file in the upload object Avram and Latch expect.
    def self.build_upload(path : String, filename : String, content_type : String) : Lucky::UploadedFile
      file = File.open(path, "rb")

      begin
        headers = HTTP::Headers.new
        headers["Content-Disposition"] = %(form-data; name="image_file"; filename="#{filename}")
        headers["Content-Type"] = content_type
        part = HTTP::FormData::Part.new(headers, file)
        Lucky::UploadedFile.new(part)
      ensure
        file.close
      end
    end

    def self.padded(index : Int32) : String
      index.to_s.rjust(4, '0')
    end

    def self.username(index : Int32) : String
      "#{USERNAME_PREFIX}_#{padded(index)}"
    end

    def self.email(index : Int32) : String
      "#{username(index)}@#{EMAIL_DOMAIN}"
    end

    def self.project_title(index : Int32) : String
      "Стресс-проект #{padded(index)}"
    end

    def self.project_slug(index : Int32) : String
      "#{PROJECT_SLUG_PREFIX}#{padded(index)}"
    end

    def self.tag_name(index : Int32) : String
      "Стресс-тег #{padded(index)}"
    end

    def self.tag_slug(index : Int32) : String
      Slugify.call(tag_name(index), TAG_SLUG_PREFIX)
    end

    def self.topic_title(index : Int32) : String
      "Стресс-тема #{padded(index)}"
    end

    def self.topic_slug(index : Int32) : String
      "#{TOPIC_SLUG_PREFIX}#{padded(index)}"
    end

    def self.project_published_at(index : Int32) : Time
      Time.utc - 30.days - (index % 500).days - (index % 24).hours
    end

    def self.topic_started_at(index : Int32) : Time
      Time.utc - 30.days - (index % 150).days - (index % 24).hours
    end

    def self.post_created_at(started_at : Time, post_index : Int32) : Time
      started_at + post_index.minutes
    end

    def self.tagline(index : Int32) : String
      [
        "Небольшой эксперимент, который вырос в отдельный проект.",
        "Игра про свет, звук и решения, которые нельзя отменить.",
        "Инструмент для тех, кто придумывает миры по вечерам.",
        "Кооперативная головоломка о странных растениях.",
        "Прототип, который мы собираем на глазах у сообщества.",
        "История о городе, который просыпается только ночью.",
      ][index % 6]
    end

    def self.project_description(index : Int32) : String
      case index % 3
      when 0
        String.build do |io|
          io << "## О проекте\n\n"
          io << "Это стресс-проект №#{padded(index)}. Он создан автоматически, чтобы проверить, "
          io << "как каталог, карточки и страницы проектов ведут себя на объёме данных.\n\n"
          io << "- жанр: #{KINDS[index % KINDS.size]};\n"
          io << "- состояние: играбельный прототип;\n"
          io << "- платформа: Windows.\n\n"
          io << "Если вы видите этот текст на реальном сайте, запустите `db.stress.cleanup`."
        end
      when 1
        String.build do |io|
          io << "# #{project_title(index)}\n\n"
          io << "Мы собрали небольшой прототип и хотим показать его сообществу. "
          io << "Основная идея — дать игроку один инструмент и менять правила вокруг него.\n\n"
          io << "## Что уже работает\n\n"
          3.times do |n|
            io << "#{n + 1}. Механика №#{n + 1}: свет, тень и звук реагируют на действия.\n"
          end
          io << "\n## Что дальше\n\n"
          io << "Планируем добавить ещё два уровня, сохранить прогресс и записать нормальный звук. "
          io << "Следите за дневниками и пишите, что стоит проверить в первую очередь.\n\n"
          io << "> Это автоматически созданный текст для нагрузочного теста."
        end
      else
        String.build do |io|
          io << "## Дневник разработки\n\n"
          io << "Проект №#{padded(index)} начался как небольшой эксперимент. "
          io << "Ниже — заметки о том, что происходит внутри.\n\n"
          5.times do |n|
            io << "### Итерация #{n + 1}\n\n"
            io << "Собрали очередную версию, проверили управление и переписали часть логики. "
            io << "В этот раз больше внимания уделили тому, как игрок понимает правила без подсказок. "
            io << "Пара решений оказалась неочевидной, зато тесты на объёме данных прошли спокойно.\n\n"
            io << "- исправлено поведение камеры;\n"
            io << "- добавлен новый звук;\n"
            io << "- обновлена страница проекта.\n\n"
          end
          io << "```\n"
          io << "state = load_level(#{index})\n"
          io << "if state.ready?\n"
          io << "  start_loop\n"
          io << "end\n"
          io << "```\n\n"
          io << "Спасибо всем, кто следит за проектом."
        end
      end
    end

    def self.post_body(topic_index : Int32, post_index : Int32) : String
      case (topic_index + post_index) % 6
      when 0
        String.build do |io|
          io << "## Впечатления от сборки №#{post_index}\n\n"
          io << "Проверил на двух машинах, разница заметна в основном на слабом железе. "
          io << "Управление отзывчивое, но после третьего уровня кадры проседают.\n\n"
          3.times do |n|
            io << "### Пункт #{n + 1}\n\n"
            io << "Попробовал пройти участок без подсказок. Получилось не сразу, "
            io << "зато правило читается из окружения. Хочется, чтобы таких мест было больше: "
            io << "игрок сам догадывается, что делать, а не читает туториал.\n\n"
          end
          io << "В целом хороший прогресс. Жду следующую итерацию."
        end
      when 1
        "Отдельно отмечу звук: стало заметно чище, особенно в наушниках. Не хватает только плавного перехода между зонами."
      when 2
        String.build do |io|
          io << "Проверил логику на длинной сессии:\n\n"
          io << "- запуск стабильный;\n"
          io << "- сохранения не теряются;\n"
          io << "- после alt-tab звук возвращается корректно.\n\n"
          io << "Мелкая ошибка: подсказка иногда остаётся на экране после смены уровня. В остальном всё хорошо."
        end
      when 3
        "Поддерживаю идею с минималистичным интерфейсом. Чем меньше элементов на экране, тем сильнее работает атмосфера."
      when 4
        String.build do |io|
          io << "Сделал несколько скриншотов и заметил, что контраст в тёмных сценах можно поднять. На светлой теме всё читается, а вот в темноте часть деталей пропадает.\n\n"
          io << "> Проверьте настройки яркости перед следующим плейтестом."
        end
      else
        "Спасибо за подробный дневник! Особенно полезно было прочитать про то, как вы принимали решение по механике. Возьму пару идей для своего проекта."
      end
    end

    def self.db_size : Int64
      AppDatabase.query_one("SELECT pg_database_size(current_database())", as: Int64)
    end

    def self.row_counts : RowCounts
      sql = <<-SQL
        SELECT
          (SELECT count(*) FROM users)::bigint AS users,
          (SELECT count(*) FROM projects)::bigint AS projects,
          (SELECT count(*) FROM tags)::bigint AS tags,
          (SELECT count(*) FROM project_tags)::bigint AS project_tags,
          (SELECT count(*) FROM screenshots)::bigint AS screenshots,
          (SELECT count(*) FROM forum_sections)::bigint AS forum_sections,
          (SELECT count(*) FROM forum_topics)::bigint AS forum_topics,
          (SELECT count(*) FROM forum_posts)::bigint AS forum_posts,
          (SELECT count(*) FROM auth_sessions)::bigint AS auth_sessions
        SQL

      row = AppDatabase.query_one(sql, as: {
        users: Int64, projects: Int64, tags: Int64, project_tags: Int64,
        screenshots: Int64, forum_sections: Int64, forum_topics: Int64,
        forum_posts: Int64, auth_sessions: Int64,
      })

      RowCounts.new(
        row[:users], row[:projects], row[:tags], row[:project_tags],
        row[:screenshots], row[:forum_sections], row[:forum_topics],
        row[:forum_posts], row[:auth_sessions]
      )
    end

    def self.stress_counts : StressCounts
      sql = <<-SQL
        SELECT
          (SELECT count(*) FROM users WHERE username ILIKE $1)::bigint AS users,
          (SELECT count(*) FROM projects WHERE slug LIKE $2)::bigint AS projects,
          (SELECT count(*) FROM tags WHERE slug LIKE $3)::bigint AS tags,
          (SELECT count(*) FROM project_tags pt JOIN projects p ON p.id = pt.project_id WHERE p.slug LIKE $2)::bigint AS project_tags,
          (SELECT count(*) FROM screenshots s JOIN projects p ON p.id = s.project_id WHERE p.slug LIKE $2)::bigint AS screenshots,
          (SELECT count(*) FROM forum_topics WHERE slug LIKE $4)::bigint AS topics,
          (SELECT count(*) FROM forum_posts fp JOIN forum_topics ft ON ft.id = fp.topic_id WHERE ft.slug LIKE $4)::bigint AS posts_in_topics,
          (SELECT count(*) FROM forum_posts fp JOIN users u ON u.id = fp.user_id WHERE u.username ILIKE $1)::bigint AS posts_by_users
        SQL

      row = AppDatabase.query_one(sql, USERNAME_SQL_PATTERN, PROJECT_SQL_PATTERN, TAG_SQL_PATTERN, TOPIC_SQL_PATTERN, as: {
        users: Int64, projects: Int64, tags: Int64, project_tags: Int64,
        screenshots: Int64, topics: Int64, posts_in_topics: Int64,
        posts_by_users: Int64,
      })

      StressCounts.new(
        row[:users], row[:projects], row[:tags], row[:project_tags],
        row[:screenshots], row[:topics], row[:posts_in_topics], row[:posts_by_users]
      )
    end

    def self.table_sizes : Array(TableSize)
      sql = <<-SQL
        SELECT
          c.relname::text AS name,
          pg_total_relation_size(c.oid)::bigint AS total,
          pg_relation_size(c.oid)::bigint AS heap,
          pg_indexes_size(c.oid)::bigint AS indexes,
          COALESCE(pg_total_relation_size(NULLIF(c.reltoastrelid, 0)), 0)::bigint AS toast
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relkind = 'r'
          AND c.relname = ANY (ARRAY[
            'users', 'projects', 'tags', 'project_tags', 'screenshots',
            'forum_sections', 'forum_topics', 'forum_posts', 'devlogs',
            'downloads', 'auth_sessions'
          ])
        ORDER BY total DESC
        SQL

      rows = AppDatabase.query_all(sql, as: {
        name: String, total: Int64, heap: Int64, indexes: Int64, toast: Int64,
      })

      rows.map do |row|
        TableSize.new(row[:name], row[:total], row[:heap], row[:indexes], row[:toast])
      end
    end

    def self.top_indexes(limit : Int32 = 10) : Array(IndexSize)
      sql = <<-SQL
        SELECT indexrelname::text AS name,
               pg_relation_size(indexrelid)::bigint AS bytes
        FROM pg_stat_user_indexes
        ORDER BY bytes DESC
        LIMIT $1
        SQL

      rows = AppDatabase.query_all(sql, limit, as: {name: String, bytes: Int64})
      rows.map { |row| IndexSize.new(row[:name], row[:bytes]) }
    end

    def self.media_size : Int64
      directory_size(File.join("public", "media"))
    end

    def self.directory_size(path : String) : Int64
      return 0_i64 unless Dir.exists?(path)

      total = 0_i64
      Dir.each_child(path) do |child|
        full = File.join(path, child)
        if File.directory?(full)
          total += directory_size(full)
        elsif File.file?(full)
          total += File.size(full)
        end
      end
      total
    end

    def self.format_bytes(bytes : Int64) : String
      units = %w[B KB MB GB TB]
      value = bytes.to_f64
      unit = 0

      while value >= 1024 && unit < units.size - 1
        value /= 1024
        unit += 1
      end

      unit.zero? ? "#{bytes} B" : "#{value.round(1)} #{units[unit]}"
    end

    def self.format_seconds(seconds : Float64) : String
      return "#{seconds.round(1)} s" if seconds < 60

      minutes = (seconds / 60).floor
      rest = (seconds % 60).round
      "#{minutes.to_i} min #{rest.to_i} s"
    end

    def self.print_marker_counts(io : IO = STDOUT) : Nil
      counts = stress_counts
      io.puts "  users:       #{counts.users}"
      io.puts "  projects:    #{counts.projects}"
      io.puts "  tags:        #{counts.tags}"
      io.puts "  project tags:#{counts.project_tags}"
      io.puts "  screenshots: #{counts.screenshots}"
      io.puts "  topics:      #{counts.topics}"
      io.puts "  posts:       #{counts.posts_in_topics}"
    end

    # Safety checks used by cleanup: stress accounts must not own or write
    # anything outside the stress markers.
    def self.non_marker_projects_for_stress_users : Int64
      AppDatabase.query_one(<<-SQL, USERNAME_SQL_PATTERN, EMAIL_SQL_PATTERN, PROJECT_SQL_PATTERN, as: Int64)
        SELECT count(*)::bigint
        FROM projects p
        WHERE p.user_id IN (
            SELECT id FROM users WHERE username ILIKE $1 AND email ILIKE $2
          )
          AND p.slug NOT LIKE $3
        SQL
    end

    def self.non_marker_topics_for_stress_users : Int64
      AppDatabase.query_one(<<-SQL, USERNAME_SQL_PATTERN, EMAIL_SQL_PATTERN, TOPIC_SQL_PATTERN, as: Int64)
        SELECT count(*)::bigint
        FROM forum_topics t
        WHERE t.user_id IN (
            SELECT id FROM users WHERE username ILIKE $1 AND email ILIKE $2
          )
          AND t.slug NOT LIKE $3
        SQL
    end

    def self.stray_posts_by_stress_users : Int64
      AppDatabase.query_one(<<-SQL, USERNAME_SQL_PATTERN, EMAIL_SQL_PATTERN, TOPIC_SQL_PATTERN, as: Int64)
        SELECT count(*)::bigint
        FROM forum_posts p
        WHERE p.user_id IN (
            SELECT id FROM users WHERE username ILIKE $1 AND email ILIKE $2
          )
          AND p.topic_id NOT IN (
            SELECT id FROM forum_topics WHERE slug LIKE $3
          )
        SQL
    end

    def self.count_posts_in_stress_topics : Int64
      AppDatabase.query_one(<<-SQL, TOPIC_SQL_PATTERN, as: Int64)
        SELECT count(*)::bigint
        FROM forum_posts p
        JOIN forum_topics t ON t.id = p.topic_id
        WHERE t.slug LIKE $1
        SQL
    end
  end
end
