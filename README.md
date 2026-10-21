# isho

Прототип витрины игр для русскоязычного рынка: каталог проектов, страницы авторов,
скриншоты и внешние ссылки на сборки. Без платежей и модерации — публикация сразу.

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
| GET | `/api/v1/users/:username` | публично |
| GET | `/api/v1/tags` | публично |
| GET | `/api/v1/health` | публично |

Тема интерфейса хранится в `users.theme` для аккаунта и в cookie `isho_theme` для
устройства. Гость без сохранённого выбора видит тему системы; `data-theme` на
`<html>` выставляет Nuxt ещё на SSR, поэтому при загрузке нет вспышки.

## Production (набросок)

```bash
# API
cd api
crystal build --release src/api.cr -o bin/api
LUCKY_ENV=production \
DATABASE_URL=postgres://user:pass@host:5432/isho_production \
APP_ORIGIN=https://your-domain.example \
COOKIE_SECURE=true \
./bin/api

# Web
cd web
npm ci && npm run build
NUXT_API_INTERNAL_BASE=http://127.0.0.1:4000 node .output/server/index.mjs
```

Caddy отдаёт `/api/*` и `/media/*` в Lucky, всё остальное — в Nuxt. Так браузер
работает с одним origin, а cookie остаются first-party. Для S3 нужно заменить
`Latch::Storage::FileSystem` на S3-хранилище в `api/config/latch.cr` и раздавать
медиа через CDN.

## Ограничения прототипа

- Скачиваемые файлы не загружаются: только внешние https-ссылки (Google Drive, Dropbox и т.п.).
- Скриншоты: JPEG/PNG/WebP до 10 МБ, до 20 на проект.
- Публикация без модерации; черновики видны только владельцу.
- Оплаты, форум, ассеты, джемы и девлоги — следующие этапы.
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


