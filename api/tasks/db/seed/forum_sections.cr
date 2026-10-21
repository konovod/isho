module Db::Seed::ForumSections
  SECTIONS = [
    {slug: "site", title: "Форум и сайт", group: "Сообщество", position: 10,
     description: "Обсуждение работы сайта, идеи и баги."},
    {slug: "offtopic", title: "Оффтоп", group: "Сообщество", position: 20,
     description: "Свободные темы и разговоры не о разработке."},
    {slug: "engines", title: "Движки и технологии", group: "Разработка", position: 30,
     description: "Unity, Unreal Engine, Godot и другие инструменты."},
    {slug: "code", title: "Код и архитектура", group: "Разработка", position: 40,
     description: "Паттерны, рефакторинг, архитектура и производительность."},
    {slug: "gamedesign", title: "Геймдизайн", group: "Разработка", position: 50,
     description: "Механики, баланс, уровни и нарратив."},
    {slug: "art-audio", title: "Арт, звук и медиа", group: "Разработка", position: 60,
     description: "Графика, анимация, музыка и звук."},
    {slug: "projects", title: "Обсуждения проектов", group: "Проекты", position: 70,
     description: "Вопросы и ответы к проектам каталога."},
    {slug: "recruitment", title: "Поиск команды", group: "Проекты", position: 80,
     description: "Ищу программиста, художника, дизайнера или звуковика."},
    {slug: "wip", title: "Показ проектов", group: "Проекты", position: 90,
     description: "Покажите проект и получите обратную связь."},
    {slug: "releases", title: "Релизы и анонсы", group: "Проекты", position: 100,
     description: "Запуски игр, трейлеры и новости."},
    {slug: "qa", title: "Вопросы и ответы", group: "Помощь", position: 110,
     description: "Помощь новичкам и ответы на общие вопросы."},
  ]

  def self.ensure_all : Nil
    SECTIONS.each do |attrs|
      if section = ForumSectionQuery.new.by_slug(attrs[:slug]).first?
        ForumSection::SaveOperation.update!(
          section,
          title: attrs[:title],
          description: attrs[:description],
          group_title: attrs[:group],
          position: attrs[:position],
        )
      else
        ForumSection::SaveOperation.create!(
          title: attrs[:title],
          slug: attrs[:slug],
          description: attrs[:description],
          group_title: attrs[:group],
          position: attrs[:position],
        )
      end
    end
  end
end
