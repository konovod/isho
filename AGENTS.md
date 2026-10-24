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
- Деплой на сервер: `.\deploy\deploy.ps1` — сборка в WSL и установка на Ubuntu
  (см. `deploy/README.md`). На сервере нет Crystal: туда едут только бинарники.
  Caddy ставится официальной сборкой из GitHub в `/usr/local/bin/caddy` (2.11.x),
  apt-версия 2.6 не используется. HTTPS включается одним `-SiteAddress https://host`,
  `APP_ORIGIN`/`APP_DOMAIN` выводятся из него. Ключ DeepSeek передаётся
  `-AiApiKey` или `$env:ISHO_AI_API_KEY` и остаётся в `/etc/isho/api.env`.

## Архитектурные правила

- **Пишем только через операции Avram** (`SaveOperation`, `DeleteOperation`, `Avram::Operation`).
  Прямые `model.update!`/`model.delete` не использовать.
- **Авторизация:** `ApiAction` по умолчанию требует сессию. Публичные экшены включают
  `Api::Auth::SkipRequireSession`. Владение проектом проверяет `RequireOwner` и отдаёт 404,
  чтобы не раскрывать черновики.
- **Сессии:** cookie `isho_auth` (сырой токен, в проде `__Host-isho_auth` — браузер
  запрещает подсунуть его с `Domain`), в БД — `auth_sessions.token_hash` (SHA-256).
  Cookie `isho_session` принадлежит Lucky и не используется для авторизации.
- **Ошибки:** единый формат `{"error":{"code","message","details"}}`; 422 — валидация.
- **JSON:** сериализаторы в `api/src/serializers`, никаких ad-hoc хешей в экшенах.
- **Медиа:** скриншоты — только через `ScreenshotUploader`, картинки в Markdown — через
  `MarkdownImageUploader` (оба Latch). Локальный диск сейчас, S3 потом. URL всегда с прямыми
  слэшами, даже на Windows. Редактор `MarkdownEditor` загружает картинки в
  `POST /api/v1/markdown_images` (multipart `image_file`, PNG/JPEG/WebP/GIF до 10 МБ),
  вставляет в текст `![alt](/media/...)`, поддерживает вставку из буфера и drag & drop;
  сами картинки привязаны к автору (`markdown_images`) и не привязаны к проекту или посту.
- **Сборки и хранилище:** `builds` хранит выложенное автором: `kind file` — файл через
  `BuildUploader` в `media/build/<uuid>/files/<имя>`, `kind web` — распакованный ZIP в
  `media/web/<uuid>/` с точкой входа `entry_path`. Внешние ссылки остаются в `downloads`.
  Загрузка кусками по 8 МБ (`POST /api/v1/projects/:slug/uploads`, `PUT
  .../uploads/:token/chunks/:index`, `.../finish`, `GET` для докачки и `DELETE` для
  отмены): Lucky читает тело запроса в память, поэтому один запрос на 300 МБ сервер не
  переживёт. `upload_sessions` держит незавершённую загрузку и резервирует её байты в
  квотах, так что параллельные загрузки не проскакивают мимо лимита. Лимиты: 300 МБ на
  сборки проекта, 1 ГБ на аккаунт (сборки + скриншоты + картинки Markdown) и 12 ГБ на
  сервер, плюс резерв 2 ГБ свободного диска; всё настраивается переменными
  `STORAGE_*_BYTES`. Квоты считает `StorageUsage` (размеры картинок — из метаданных
  Latch). Веб-сборки отдаются с CSP `sandbox` и `X-Content-Type-Options: nosniff`,
  файлы — с `Content-Disposition: attachment`; это делает `MediaHeadersHandler`.
  Играм нужны Cache Storage, IndexedDB и localStorage (кеш сборки Unity, `PlayerPrefs`),
  а в opaque origin их нет, поэтому на отдельном media-origin (`MEDIA_ORIGIN`,
  задаётся деплою через `-MediaAddress`, например `https://isho-games.duckdns.org`)
  к sandbox добавляется `allow-same-origin`: там нет cookie сайта. На основном origin
  флага нет никогда. Медиа-хост берут **отдельным именем**, а не поддоменом сайта:
  поддомен делит registrable domain и может ставить cookie на родителя (cookie tossing).
  Сжатые файлы Unity (`*.js.br`, `*.wasm.br`, `*.data.br`, `*.gz`) отдаёт
  `WebBuildAssetsHandler` — с `Content-Encoding` и типом исходного файла, иначе
  загрузчик получает `application/octet-stream` и `nosniff` не даёт запустить
  framework. Архив проверяется `WebBuildArchive` (zip-slip, лимит файлов,
  распакованный объём, `index.html`). Остатки подметают `tasks storage.stats` и
  `tasks storage.cleanup` (таймер `isho-storage.timer`).
- **Счётчики сборок:** `builds.downloads_count` растёт при скачивании файла,
  `builds.launches_count` — когда открывают стартовую страницу веб-сборки. Считает
  `BuildUsageHandler` (перед статикой, атомарным `UPDATE` в `BuildUsage`); повторные
  `Range` при докачке и `HEAD` не считаются, для HTML веб-сборок ставится
  `Cache-Control: no-cache`, чтобы запуски не терялись в кеше браузера. Цифры
  best-effort и видны только владельцу проекта: `BuildSerializer` добавляет их при
  `with_usage`, публичный `show` включает флаг лишь для автора.
- **Контент-фильтры:** у проекта есть `nsfw` (18+) и `ai_usage`
  (`ai_free|partial|significant|full`, от меньшего к большему). Гости не видят 18+;
  пользователь хранит `users.show_nsfw` и `users.max_ai_usage` и меняет их на
  `/settings` (`PATCH /api/v1/me/preferences`). Скрытие действует в каталоге, профилях,
  счётчиках тегов, форуме и по прямым ссылкам (404); владелец и админ видят всё.
- **Параметры:** JSON-запросы вложены в ключ модели (`project`, `user`, `download`),
  массивы (`tag_names`, `ids`) — на верхнем уровне. `tag_names` — имена тегов, новые
  создаются автоматически (`tag_slugs` поддерживается для старых клиентов). Скриншоты —
  multipart, поле `image_file`. Вход — `user.login` (почта или ник, без учёта регистра);
  `user.email` принимается как устаревший вариант. На неизвестный логин и неверный пароль
  ответ одинаковый, чтобы не раскрывать существующие аккаунты.
- **Теги:** общие для всех проектов. Автор вводит имя: сначала поиск по имени без учёта
  регистра, затем по slug, иначе `SaveTag` создаёт новый тег (slug через `Slugify`, до
  40 символов, до 8 тегов на проект). `GET /api/v1/tags` по умолчанию отдаёт только теги,
  которые видит зритель минимум на двух опубликованных проектах (`min_projects`, по
  умолчанию 2): так из каталога выпадают теги одной игры и 18+-теги, у которых для гостя
  нет ни одного видимого проекта. Редактор запрашивает `min_projects=1`, чтобы
  автодополнение не теряло редкие теги.
- **Фронтенд:** `useApi()` для всех запросов (прокси и cookie-forwarding на SSR),
  `useAuth()` для состояния пользователя. Не класть токены в localStorage.
- **Markdown:** описания проектов, девлоги и форум хранятся как есть, рендерятся на фронте
  через `markdown-it` (`web/app/utils/markdown.ts`) с `html: false`; экшены API текст
  не парсят. Изображения — обычный `![alt](url)`; Rutube-видео — тот же синтаксис с
  `rutube.ru/video/<id>/` (или `play/embed`, приватная ссылка, голый id), рендерится
  ленивым iframe. Спойлеры — `:::spoiler Заголовок` … `:::` (`<details>`, заголовок
  необязателен). Код в ```-блоках подсвечивается highlight.js по указанному языку.
  Девлоги длиннее 600 символов показываются сниппетом со ссылкой на
  `/p/:slug/devlog/:devlogSlug`.
- **Форум:** разделы (`forum_sections`), темы (`forum_topics`) и сообщения (`forum_posts`).
  Тело темы — её первый `forum_post`. Темы с `project_id` относятся к разделу `projects`
  и видны по правилам видимости проекта; в общем списке раздела показываются только темы
  опубликованных проектов. Разделы создаются в админке (`/moderation` → «Форум»,
  `GET`/`POST`/`PATCH`/`DELETE /api/v1/admin/forum/sections`); `Db::Seed::ForumSections`
  наполняет только пустую базу и больше не перезаписывает существующие разделы, иначе
  правки из админки слетали бы при каждом деплое. Slug входит в URL `/forum/:slug`, поэтому
  меняется только у пустого раздела и никогда у `projects`; удалить можно тоже только пустой
  раздел (каскад иначе унёс бы темы), `projects` не удаляется вовсе. Слаги тем уникальны
  в разделе и не меняются при правке заголовка. Цитата хранит снимок автора и текста; `quoted_post_id` без FK.
  Цитировать можно фрагмент: клиент присылает `quote_text` в `forum_post` (выделенный
  текст, до 2000 символов), сервер сохраняет его вместо полного тела, пустой — весь пост.
  Фрагмент не сверяется с исходником (выделение из отрендеренного Markdown не совпадает
  с текстом поста). Ссылка на сообщение строится из `quote.post_id` и `quote.page`;
  страница пересчитывается при чтении, чтобы ссылка не устаревала после удалений.
- **Непрочитанное:** `forum_topic_reads` (`user_id`, `topic_id`, `read_count`) хранит,
  сколько сообщений темы пользователь видел; строки нет — тема не открывалась. Фронт
  отмечает прочтение через `POST /api/v1/forum/topics/:id/read` последним сообщением
  просмотренной страницы. Автор последнего ответа денормализован в
  `forum_topics.last_post_user_id` и обновляется операциями создания/удаления сообщений.
- **Реакции:** `forum_post_reactions` (`post_id`, `user_id`, `kind` `like|dislike`,
  уникальность `[post_id, user_id]`). Счётчики не денормализованы — их считает
  `ForumReactions` одним запросом на страницу, поэтому удаление пользователя или поста
  не оставляет стухших чисел. `POST /api/v1/forum/posts/:id/reactions` ставит голос,
  повтор снимает, другой заменяет; за своё сообщение нельзя (`422 own_post`), забаненному
  `403`. Попап — `GET .../reactions?kind=like|dislike`: 10 последних и `truncated`.
- **ИИ на форуме:** `Ai::Client` (`api/src/services/ai/`) ходит в DeepSeek через
  OpenAI-совместимый `/chat/completions` на stdlib `HTTP::Client`; без `AI_API_KEY`
  всё выключено, `AI_ENABLED=off` — аварийный выключатель. Долгие вызовы не держат
  запрос: ответ на тему и флеир — задачи в `ai_jobs`, их по одной разбирает
  `bin/tasks ai.worker` (сервис `isho-ai.service`, unit в `deploy/server`), а
  `bin/tasks ai.stats` показывает расход и ошибки. Лимиты: 3 ответа ИИ в сутки на
  аккаунт (плюс возраст 3 дня и 5 сообщений), 10 подсказок раздела в час и 30 в сутки,
  флеир не чаще 24 часов; общий потолок — `AI_DAILY_JOBS`/`AI_DAILY_INPUT_TOKENS`/
  `AI_DAILY_OUTPUT_TOKENS`, после него воркер спит. Ответ ИИ лежит не в
  `forum_posts`, а в `forum_ai_answers` (одна на тему), иначе поехали бы
  `replies_count`, `last_post_at` и непрочитанное; показывается под спойлером после
  первого поста, `GET /api/v1/forum/topics/:id/ai_answer` — для опроса, удаляет
  только админ. Подсказка раздела (`POST /api/v1/forum/topic_suggestions`) —
  единственный синхронный вызов, с таймаутом и без блокировки создания темы.
  Флеир (`users.ai_flair`, до 64 символов) собирается из 100 последних сообщений,
  скрывается галочкой `users.ai_flair_enabled`, чистится `tasks ai.clear_flair <кто>`.
  Раздел можно выключить в админке (`forum_sections.ai_answers_enabled`), у `projects`
  всегда выключено. Спеки используют `AiFakeBackend` из `spec/support/ai_fake.cr` и
  никогда не ходят в сеть.
- **Модерация:** `users.is_admin` сейчас единственная роль модератора (`User#moderator?`).
  Авторы редактируют свои сообщения и название темы, удалять сообщения/темы может только
  админ. Первое сообщение темы отдельно не удаляется — только тема целиком. Уведомлений
  об удалении нет. Админ также может удалить пользователя и снять чужой проект с публикации
  с причиной: причина лежит в `projects.moderation_note`, видна только автору и админу и
  очищается, когда автор публикует проект снова. Назначить админа: `tasks.exe db.make_admin <email>`.
- **Бан:** история лежит в `user_bans` (причина, `expires_at`, кто забанил `banned_by_id`,
  кто снял `lifted_by_id`); активен бан, у которого `lifted_at IS NULL` и `expires_at`
  в будущем, поэтому истекает сам без задач. API: `POST`/`DELETE
  /api/v1/admin/users/:username/ban`, история — `GET .../bans`; банить себя и админов
  нельзя. Забаненный входит и читает, но `RequireNotBanned` в проектных и форумных
  экшенах отдаёт `403 user_banned` на создание/правку контента. Фронт уводит его на
  `/banned` с причиной и отсчётом. Контент и публикации бана не удаляются и не снимаются.
- **Удаление пользователя:** каскады в БД удаляют его темы и сообщения, но перед удалением
  пользователя нужно вызвать `DeleteUserContent`, иначе денормализованные
  `replies_count`/`last_post_at` останутся неверными. Для аккаунта целиком используйте
  `DeleteUserAccount` (он вызывает `DeleteUserContent`, удаляет файлы скриншотов и
  осиротевшие теги). Почта удалённого аккаунта попадает в `blocked_emails` (снимок
  `username`, уникальность без учёта регистра), и `SignUpUser` отклоняет регистрацию с
  этого адреса (`422`, `email: is not allowed`). Список ведётся в окне модерации:
  `GET`/`DELETE /api/v1/admin/blocked_emails`; удаление записи снова разрешает регистрацию.
- **Подтверждение почты:** регистрация создаёт аккаунт с `users.email_confirmed_at = NULL`
  и отправляет письмо со ссылкой `/confirm_email?token=...`. Токен одноразовый, в БД
  лежит только SHA-256, срок — 24 часа, повторная отправка не чаще 5 минут
  (`EmailConfirmation`, `SaveEmailConfirmation`, `ConfirmUserEmail`). Пока адрес не
  подтверждён, вход и черновики работают, а публикация проектов и создание тем/сообщений
  форума отдают 403 `email_not_confirmed` (`Api::Auth::RequireConfirmedEmail`).
  Транспорт: `MAIL_ADAPTER=dev|smtp|sendgrid` (`MAIL_FROM`, `SMTP_*`); в тестах всегда
  dev-адаптер. `EMAIL_CONFIRMATION=off` отключает требование, а `tasks.exe db.confirm_email
  <email>` подтверждает вручную. Письма собирает `EmailConfirmationEmail`.
- **Пароли:** длина 6–72 символа (72 — ограничение BCrypt), требований к составу нет.
  Проверка одна на регистрацию и сброс — `PasswordValidations`.
- **Сброс пароля:** `POST /api/v1/password_resets` (`user.email`) всегда отвечает
  `{sent: true}` и не раскрывает, существует ли аккаунт; письмо уходит не чаще раза в
  5 минут. Токен (`users.password_reset_token_hash`, SHA-256) живёт 1 час. Страница
  `/reset_password?token=...` отправляет `user.password`/`password_confirmation` на
  `POST /api/v1/password_resets/:token`: пароль, очистка токена и подтверждение почты
  пишутся одной операцией `ResetPassword`, затем закрываются все сессии пользователя
  (`Auth::Session.destroy_all`) и открывается новая. Письма собирает
  `PasswordResetEmail`, сервис — `PasswordReset`.
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
- **`.env` перекрывает окружение:** `LuckyEnv.load?` пишет значения файла в `ENV` поверх уже
  установленных, поэтому `LUCKY_ENV` и `DEV_PORT` в `api/.env` уводят спеки в dev-среду и
  dev-базу. Держите в `.env` только то, что нужно рантайму (например, `MAIL_*`).

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
закрепление и закрытие тем), ассеты, джемы, e-mail.


