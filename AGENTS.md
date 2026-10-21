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
- **UI:** русский язык, тёмная тема, стили в `web/app/assets/css/main.css`.

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

Платежи (YooKassa/CloudPayments/T-Bank), S3, модерация, форум, ассеты, джемы,
девлоги, Markdown-описания, загрузка самих сборок, e-mail.


