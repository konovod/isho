# Development seed data. Safe to run more than once.
class Db::Seed::SampleData < LuckyTask::Task
  summary "Add sample database records helpful for development"

  DEMO_EMAIL    = "demo@isho.local"
  DEMO_USERNAME = "demo"
  DEMO_PASSWORD = "password1234"

  def call
    user = find_or_create_user
    ensure_tags
    Db::Seed::ForumSections.ensure_all
    night_shift = create_project(user, "Ночная смена", "Атмосферный хоррор про одинокий маяк.", "Ты — смотритель маяка. На улице шторм, а в дверь кто-то стучит. Игра про звук, свет и решения, которые нельзя отменить.", "game", %w[Экшен Хоррор])
    create_project(user, "Пиксельный сад", "Уютная головоломка о выращивании странных растений.", "Каждый цветок меняет правила сада. Собирай семена, переставляй грядки и найди путь к сердцу сада.", "game", %w[Головоломка Уютное])
    create_project(user, "Карта миров", "Инструмент для писателей и мастеров НРИ.", "Описывай регионы, связи между ними и события. Экспортируй карту в Markdown и используй в своей игре.", "tool", %w[Мирастроение])
    ensure_devlogs(night_shift) if night_shift
    ensure_forum(user, night_shift)

    puts "Done adding sample data"
  end

  private def find_or_create_user : User
    UserQuery.new.username(DEMO_USERNAME).first? || begin
      SignUpUser.create!(
        email: DEMO_EMAIL,
        username: DEMO_USERNAME,
        display_name: "Демо-автор",
        password: DEMO_PASSWORD,
        password_confirmation: DEMO_PASSWORD,
      )
    end
  end

  private def ensure_tags
    {
      "action"        => "Экшен",
      "horror"        => "Хоррор",
      "puzzle"        => "Головоломка",
      "cozy"          => "Уютное",
      "rpg"           => "RPG",
      "worldbuilding" => "Мирастроение",
    }.each do |slug, name|
      if tag = TagQuery.new.slug(slug).first?
        Tag::SaveOperation.update!(tag, name: name) if tag.name != name
      else
        Tag::SaveOperation.create!(name: name, slug: slug)
      end
    end
  end

  private def create_project(user : User, title : String, tagline : String, description : String, kind : String, tag_names : Array(String)) : Project?
    slug = Slugify.call(title)
    if existing = ProjectQuery.new.slug(slug).first?
      return existing
    end

    project = SaveProject.create!(
      title: title,
      tagline: tagline,
      description: description,
      kind: kind,
      user_id: user.id,
    )

    SetProjectTags.new(project: project, tag_names: tag_names).run
    ChangeProjectStatus.new(project: project, publish: true).run
    project
  end

  private def ensure_devlogs(project : Project) : Nil
    return if DevlogQuery.new.project_id(project.id).select_count > 0

    SaveDevlog.create!(
      project_id: project.id,
      title: "Прототип готов",
      body: [
        "Собрали первый играбельный прототип: маяк, шторм и один этаж.",
        "",
        "Дальше — звук шагов на лестнице и три концовки.",
      ].join("\n"),
    )

    SaveDevlog.create!(
      project_id: project.id,
      title: "Дневник разработки: как устроен свет",
      body: [
        "## Зачем маяку свет",
        "",
        "Свет в «Ночной смене» — не только атмосфера. Это **ресурс**, который игрок тратит, чтобы видеть мир, и который привлекает то, что живёт снаружи.",
        "",
        "### Три состояния фонаря",
        "",
        "1. **Яркий** — видно далеко, но снаружи тоже замечают.",
        "2. **Тусклый** — безопаснее, зато часть подсказок исчезает.",
        "3. **Выключен** — слышно больше, но каждый шорох кажется шагом.",
        "",
        "> Главная задача — заставить игрока выбрать темноту добровольно.",
        "",
        "### Что уже работает",
        "",
        "- плавное затухание света и тени;",
        "- шум, который реагирует на движение;",
        "- журнал находок с короткими записями.",
        "",
        "```",
        "light = clamp(light - drain * delta, 0, 1)",
        "```",
        "",
        "В следующей записи расскажу про маяк изнутри и покажу, как выглядит лестница на рассвете. Если хотите проверить прототип — ссылка на сборку уже на странице проекта.",
      ].join("\n"),
    )
  end

  private def ensure_forum(user : User, project : Project?) : Nil
    site = ForumSectionQuery.new.by_slug("site").first?
    qa = ForumSectionQuery.new.by_slug("qa").first?
    projects = ForumSectionQuery.new.by_slug("projects").first?
    return unless site && qa && projects

    create_topic(site, user, "Как вам новый форум?",
      "Это первый раздел форума. Здесь можно предложить идеи, рассказать о баге или просто поздороваться.\n\nПишите в Markdown — он такой же, как в девлогах.")

    create_topic(qa, user, "С чего начать разработку первой игры?",
      "Хочется сделать небольшую игру, но не понимаю, с чего начать: движок, идея или сразу прототип?\n\nПоделитесь опытом: что помогло вам дойти до первого релиза.")

    if project
      create_topic(projects, user, "ЧаВо: как запустить прототип «Ночной смены»?",
        "Скачайте сборку по ссылке на странице проекта, распакуйте архив и запустите `night-shift.exe`.\n\nЕсли игра не стартует, напишите версию Windows и текст ошибки — разберёмся.",
        project)
    end
  end

  private def create_topic(section : ForumSection, user : User, title : String, body : String, project : Project? = nil) : Nil
    existing = if project
                 ForumTopicQuery.new.for_project(project.id).first?
               else
                 ForumTopicQuery.new.for_section(section.id).first?
               end
    return if existing

    topic = CreateForumTopic.run!(
      section: section,
      user: user,
      project: project,
      title: title,
      body: body,
    )

    first_post = ForumPostQuery.new.for_topic(topic.id).chronological.first?

    CreateForumPost.run!(
      topic: topic,
      user: user,
      body: "Спасибо, что открыли тему! Буду дополнять её по мере вопросов.",
      quoted_post_id: first_post.try(&.id),
    )
  end
end
