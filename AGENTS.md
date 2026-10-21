# AGENTS.md

Правила для агентов и людей, которые меняют этот репозиторий.

## Что это

Прототип витрины игр (isho): Crystal/Lucky API + Nuxt 4 SSR. Один origin в
продакшене: Caddy отдаёт `/api/*` и `/media/*` в Lucky, остальное — в Nuxt.

## Запуск

- Оба сервера: `.\dev.ps1` из корня (API :4000, web :3000; Ctrl+C останавливает оба).
- API: `cd api && .\script\dev-api.ps1` (Windows) — порт 4000.
- Web: `cd web && npm run dev` — порт 3000, проксирует `/api` и `/media` на 4000.
- БД: `docker compose up -d db` (PostgreSQL 16, `postgres/postgres`, порт 5432).
- Миграции: `cd api && .\bin\tasks.exe db.migrate` после `crystal build tasks.cr -o bin/tasks.exe`.
- Сид: `.\bin\tasks.exe db.seed.sample_data`.

## Архитектурные правила

- **Пишем только через операции Avram** (`SaveOperation`, `DeleteOperation`, `Avram::Operation`).
  Прямые `model.update!`/`model.delete` не использовать.
- **Авторизация:** `ApiAction` по умолчанию требует сессию. Публичные экшены включают
  `Api::Auth::SkipRequireSession`. Владение проектом проверяет `RequireOwner` и отдаёт 404,
  чтобы не раскрывать черновики.
- **Сессии:** cookie `isho_auth` (сырой токен), в БД — `auth_sessions.token_hash` (SHA-256).
  Cookie `isho_session` принадлежит Lucky и не используется для авторизации.
- **Ошибки:** единый формат `{"error":{"code","message","details"}}`; 422 — валидация.
- **JSON:** сериализаторы в `api/src/serializers`, никаких ad-hoc хешей в экшенах.
- **Медиа:** только через `ScreenshotUploader` (Latch). Локальный диск сейчас, S3 потом.
  URL всегда с прямыми слэшами, даже на Windows.
- **Параметры:** JSON-запросы вложены в ключ модели (`project`, `user`, `download`),
  массивы (`tag_names`, `ids`) — на верхнем уровне. `tag_names` — имена тегов, новые
  создаются автоматически (`tag_slugs` поддерживается для старых клиентов). Скриншоты —
  multipart, поле `image_file`.
- **Теги:** общие для всех проектов. Автор вводит имя: сначала поиск по имени без учёта
  регистра, затем по slug, иначе `SaveTag` создаёт новый тег (slug через `Slugify`, до
  40 символов, до 8 тегов на проект).
- **Фронтенд:** `useApi()` для всех запросов (прокси и cookie-forwarding на SSR),
  `useAuth()` для состояния пользователя. Не класть токены в localStorage.
- **Markdown:** описания проектов, девлоги и форум хранятся как есть, рендерятся на фронте
  через `markdown-it` (`web/app/utils/markdown.ts`) с `html: false`; экшены API текст
  не парсят. Девлоги длиннее 600 символов показываются сниппетом со ссылкой на
  `/p/:slug/devlog/:devlogSlug`.
- **Форум:** разделы (`forum_sections`), темы (`forum_topics`) и сообщения (`forum_posts`).
  Тело темы — её первый `forum_post`. Темы с `project_id` относятся к разделу `projects`
  и видны по правилам видимости проекта; в общем списке раздела показываются только темы
  опубликованных проектов. Разделы создаются `Db::Seed::ForumSections` (нужен
  `db.seed.required_data`). Слаги тем уникальны в разделе и не меняются при правке
  заголовка. Цитата хранит снимок автора и текста; `quoted_post_id` без FK.
- **Модерация:** `users.is_admin` сейчас единственная роль модератора (`User#moderator?`).
  Авторы редактируют свои сообщения и название темы, удалять сообщения/темы может только
  админ. Первое сообщение темы отдельно не удаляется — только тема целиком. Уведомлений
  об удалении нет. Админ также может удалить пользователя и снять чужой проект с публикации
  с причиной: причина лежит в `projects.moderation_note`, видна только автору и админу и
  очищается, когда автор публикует проект снова. Назначить админа: `tasks.exe db.make_admin <email>`.
- **Удаление пользователя:** каскады в БД удаляют его темы и сообщения, но перед удалением
  пользователя нужно вызвать `DeleteUserContent`, иначе денормализованные
  `replies_count`/`last_post_at` останутся неверными. Для аккаунта целиком используйте
  `DeleteUserAccount` (он вызывает `DeleteUserContent`, удаляет файлы скриншотов и
  осиротевшие теги).
- **UI:** русский язык, светлая и тёмная темы, стили в `web/app/assets/css/main.css`.
  Палитра — токены через `light-dark()`; выбор хранится в cookie `isho_theme` и в
  `users.theme`, атрибут `data-theme` на `<html>` Nuxt ставит на SSR.

## Ловушки

- **Windows + ImageMagick:** нужны `MAGICK_HOME`, `MAGICK_CONFIGURE_PATH`,
  `MAGICK_CODER_MODULE_PATH`; иначе Latch не ресайзит картинки. Скрипт `script/dev-api.ps1` уже это делает.
- **Windows:** `Signal::INT.trap` не реализован — в `start_server.cr` он обёрнут в `{% unless flag?(:win32) %}`.
- **Latch 0.3.2** тянет `awscr-s3` даже при файловом хранилище; зависимость добавлена в `shard.yml`.
- **Latch-валидации** (`validate_file_size_of`) несовместимы с Avram 1.5; размер и MIME проверяются в экшене.
- **Avram:** `add_belongs_to` уже создаёт индекс — не добавлять `add_index :project_id` повторно.
- **Avram:** у моделей нет `.create!`; использовать `Model::SaveOperation.create!`.
- **Timestamps:** модели Avram ожидают `created_at`/`updated_at`; не забывать `add_timestamps`.
- **Cookie:** не называть auth-cookie так же, как `Lucky::Session.settings.key`, иначе Lucky перезапишет значение.
- **Windows:** собранный `api.exe` блокируется запущенным процессом; перед пересборкой остановить сервер.

## Проверки перед коммитом

```powershell
cd api
crystal tool format --check src spec
.\script\spec.ps1

cd ..\web
npm run typecheck
npm run build
```

На Windows `crystal spec` падает с `Process terminated abnormally`; используйте
`script/spec.ps1` (собирает и запускает `bin/specs.exe`).

## Следующие шаги (не реализовано)

Платежи (YooKassa/CloudPayments/T-Bank), S3, расширенная модерация (роли, уведомления,
закрепление и закрытие тем), ассеты, джемы, загрузка самих сборок, e-mail.


