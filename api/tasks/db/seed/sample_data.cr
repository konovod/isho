# Development seed data. Safe to run more than once.
class Db::Seed::SampleData < LuckyTask::Task
  summary "Add sample database records helpful for development"

  DEMO_EMAIL    = "demo@isho.local"
  DEMO_USERNAME = "demo"
  DEMO_PASSWORD = "password1234"

  def call
    user = find_or_create_user
    ensure_tags
    create_project(user, "Ночная смена", "Атмосферный хоррор про одинокий маяк.", "Ты — смотритель маяка. На улице шторм, а в дверь кто-то стучит. Игра про звук, свет и решения, которые нельзя отменить.", "game", %w[action horror])
    create_project(user, "Пиксельный сад", "Уютная головоломка о выращивании странных растений.", "Каждый цветок меняет правила сада. Собирай семена, переставляй грядки и найди путь к сердцу сада.", "game", %w[puzzle cozy])
    create_project(user, "Карта миров", "Инструмент для писателей и мастеров НРИ.", "Описывай регионы, связи между ними и события. Экспортируй карту в Markdown и используй в своей игре.", "tool", %w[worldbuilding])

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

  private def create_project(user : User, title : String, tagline : String, description : String, kind : String, tags : Array(String))
    slug = Slugify.call(title)
    return if ProjectQuery.new.slug(slug).first?

    project = SaveProject.create!(
      title: title,
      tagline: tagline,
      description: description,
      kind: kind,
      user_id: user.id,
    )

    SetProjectTags.new(project: project, tag_slugs: tags).run
    ChangeProjectStatus.new(project: project, publish: true).run
  end
end
