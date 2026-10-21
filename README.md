# isho

Прототип витрины игр для русскоязычного рынка: каталог проектов, страницы авторов,
скриншоты, девлоги, форум и внешние ссылки на сборки. Без платежей; модерация форума
доступна администраторам.

## Стек

- **API:** Crystal 1.19 + [Lucky 1.5](https://luckyframework.org) в API-only режиме, Avram, PostgreSQL 16.
- **Фронтенд:** Nuxt 4 (Vue 3 + TypeScript), SSR для публичных страниц.
- **Медиа:** [Latch](https://github.com/wout/latch) + ImageMagick, локальный диск в прототипе.
  Интерфейс хранилища совпадает с S3, поэтому переезд — вопрос конфигурации.
- **Сессии:** непрозрачный токен в httpOnly cookie + SHA-256 хеш в таблице `auth_sessions`.

## Быстрый старт (Windows, dev)

Нужны: Crystal 1.19.x, Node 22+, PostgreSQL 16 (или Docker), ImageMagick 7.

```powershell
# 1. База
docker compose up -d db

# 2. Зависимости и база
cd api
shards install
crystal build tasks.cr -o bin/tasks.exe
.\bin\tasks.exe db.create
.\bin\tasks.exe db.migrate
.\bin\tasks.exe db.seed.sample_data
cd ..\web
npm install
cd ..

# 3. Оба сервера одной командой
.\dev.ps1                # API :4000, web :3000
```

`dev.ps1` собирает и запускает API, ждёт `/api/v1/health`, затем поднимает Nuxt.
Ctrl+C останавливает оба сервера. По отдельности: `cd api; .\script\dev-api.ps1`
и `cd web; npm run dev`.

Демо-аккаунт после сида: `demo@isho.local` / `password1234`.

### ImageMagick на Windows

Scoop-сборка не прописывает пути к конфигам. `api/script/dev-api.ps1` выставляет
`MAGICK_HOME`, `MAGICK_CONFIGURE_PATH` и `MAGICK_CODER_MODULE_PATH` автоматически.
Если ImageMagick установлен в другое место, поправьте путь в скрипте.

## Структура

```
api/                 Lucky API
  src/actions/api/v1 маршруты
  src/models         Avram-модели
  src/operations     запись в БД
  src/serializers    JSON
  src/uploaders      Latch-загрузчик скриншотов
  db/migrations      миграции
  tasks/             задачи (db.seed.sample_data)
web/                 Nuxt 4
  app/pages          страницы
  app/components     компоненты
  app/composables    useApi / useAuth / useTheme / useFormat
docker-compose.yml   PostgreSQL
```

## API

Все ответы — JSON. Ошибки: `{"error":{"code","message","details"}}`.

Вход (`POST /api/v1/sign_ins`) принимает `user.login` — почту или ник без учёта регистра;
`user.email` поддерживается для старых клиентов.

| Метод | Путь | Доступ |
|---|---|---|
| POST | `/api/v1/sign_ups` | публично |
| POST | `/api/v1/sign_ins` | публично |
| DELETE | `/api/v1/sign_ins` | вход |
| GET | `/api/v1/me` | вход |
| PATCH | `/api/v1/me` | вход |
| PATCH | `/api/v1/me/theme` | вход |
| GET | `/api/v1/me/projects` | вход |
| GET | `/api/v1/projects` | публично |
| GET | `/api/v1/projects/:slug` | публично (черновик — владельцу) |
| POST | `/api/v1/projects` | вход |
| PATCH | `/api/v1/projects/:slug` | владелец |
| DELETE | `/api/v1/projects/:slug` | владелец |
| POST | `/api/v1/projects/:slug/publish` | владелец |
| POST | `/api/v1/projects/:slug/unpublish` | владелец |
| POST | `/api/v1/projects/:slug/screenshots` | владелец, multipart `image_file` |
| PATCH | `/api/v1/projects/:slug/screenshots/:id` | владелец |
| DELETE | `/api/v1/projects/:slug/screenshots/:id` | владелец |
| PUT | `/api/v1/projects/:slug/screenshots/order` | владелец |
| POST | `/api/v1/projects/:slug/downloads` | владелец |
| DELETE | `/api/v1/projects/:slug/downloads/:id` | владелец |
| GET | `/api/v1/projects/:slug/devlogs` | публично (черновик — владельцу) |
| GET | `/api/v1/projects/:slug/devlogs/:devlog_slug` | публично (черновик — владельцу) |
| POST | `/api/v1/projects/:slug/devlogs` | владелец |
| PATCH | `/api/v1/projects/:slug/devlogs/:id` | владелец |
| DELETE | `/api/v1/projects/:slug/devlogs/:id` | владелец |
| GET | `/api/v1/forum/sections` | публично |
| GET | `/api/v1/forum/sections/:section_slug` | публично |
| GET | `/api/v1/forum/sections/:section_slug/topics/:topic_slug` | публично (черновик — владельцу) |
| POST | `/api/v1/forum/sections/:section_slug/topics` | вход |
| PATCH | `/api/v1/forum/topics/:id` | автор или админ |
| DELETE | `/api/v1/forum/topics/:id` | админ |
| POST | `/api/v1/forum/topics/:id/posts` | вход |
| PATCH | `/api/v1/forum/posts/:id` | автор или админ |
| DELETE | `/api/v1/forum/posts/:id` | админ |
| GET | `/api/v1/projects/:slug/forum/topics` | публично (черновик — владельцу) |
| POST | `/api/v1/projects/:slug/forum/topics` | вход |
| GET | `/api/v1/users/:username` | публично |
| GET | `/api/v1/tags` | публично |
| GET | `/api/v1/health` | публично |

Тема интерфейса хранится в `users.theme` для аккаунта и в cookie `isho_theme` для
устройства. Гость без сохранённого выбора видит тему системы; `data-theme` на
`<html>` выставляет Nuxt ещё на SSR, поэтому при загрузке нет вспышки.

Форум состоит из разделов (`forum_sections`), тем (`forum_topics`) и сообщений
(`forum_posts`). Разделы создаются задачей `db.seed.required_data`; список правится в
`api/tasks/db/seed/forum_sections.cr`. Тема может быть привязана к проекту
(`forum_topics.project_id`) и тогда попадает в раздел `projects`. Тело темы — её первое
сообщение. Ответы и темы пишутся в Markdown и рендерятся на фронте тем же
`markdown-it`, что и девлоги. Цитата хранит снимок автора и текста на момент ответа,
поэтому переживает редактирование или удаление оригинала.

Администраторы (`users.is_admin`) могут удалять любые сообщения и темы; авторы
редактируют свои сообщения и название темы, но удалять их может только администратор.
Уведомлений об удалении пока нет. При удалении пользователя его темы и сообщения
удаляются: каскад в БД и операция `DeleteUserContent`, которая пересчитывает счётчики
тем.

## Production

Готовые скрипты лежат в `deploy/` (подробности — `deploy/README.md`). Сборка идёт
локально в WSL (Ubuntu 24.04), на сервер уезжают только release-бинарники Lucky
и серверный бандл Nuxt:

```powershell
$env:ISHO_SSH_PASSWORD = '<пароль root>'
.\deploy\deploy.ps1                       # собрать и раскатать, http://<ip>
.\deploy\deploy.ps1 -SampleData           # плюс демо-проекты и demo@isho.local
.\deploy\deploy.ps1 -SiteAddress https://vm4775508.firstbyte.club   # домен + TLS
```

На сервере `bootstrap.sh` ставит PostgreSQL, Node.js 22, Caddy и ImageMagick,
создаёт БД, пользователя `isho`, swap и службы `isho-api`, `isho-web`, `caddy`.
Секреты и параметры окружения — в `/etc/isho/api.env` и `/etc/isho/web.env`;
при повторном деплое они сохраняются. API слушает `127.0.0.1:4000` (порт задаётся
`HOST`/`PORT`), Nuxt — `127.0.0.1:3000`, наружу смотрит только Caddy.

Caddy отдаёт `/api/*` и `/media/*` в Lucky, всё остальное — в Nuxt. Так браузер
работает с одним origin, а cookie остаются first-party. Для S3 нужно заменить
`Latch::Storage::FileSystem` на S3-хранилище в `api/config/latch.cr` и раздавать
медиа через CDN.

## Ограничения прототипа

- Скачиваемые файлы не загружаются: только внешние https-ссылки (Google Drive, Dropbox и т.п.).
- Скриншоты: JPEG/PNG/WebP до 10 МБ, до 20 на проект.
- Публикация проектов без модерации; черновики видны только владельцу.
- Описания проектов, девлоги и форум — Markdown (`markdown-it`, сырой HTML отключён).
  Короткие девлоги (до 600 символов) показываются на странице проекта целиком, длинные —
  отдельной страницей со ссылкой из ленты.
- Форум: без вложений, уведомлений, закрепления и закрытия тем, поиска и rate limit.
  Удаление сообщений и тем — только администраторами.
- Оплаты, S3, ассеты, джемы и загрузка самих сборок — следующие этапы.
- UI на русском, валюта и платежи не подключены.

## Тесты

```powershell
cd api
.\script\spec.ps1
```

`crystal spec` на Windows падает с `Process terminated abnormally` (Crystal 1.19),
поэтому скрипт собирает `spec/all_specs.cr` в `bin/specs.exe` и запускает его напрямую.
Спеки используют отдельную БД `isho_test` (создаётся автоматически) и in-memory
хранилище Latch. Для обработки изображений в тестах нужен ImageMagick в PATH.


