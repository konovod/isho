# isho

Прототип витрины игр для русскоязычного рынка: каталог проектов, страницы авторов,
скриншоты, дневники, форум и внешние ссылки на сборки. Без платежей; модерация форума
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

Веб-сборки локально по умолчанию живут на одном origin с сайтом. Чтобы проверить
их как на сервере (отдельный origin на проект, кеш и сейвы игры), запустите API с
`MEDIA_ORIGIN=http://localhost:4000`: `play_url` станет абсолютным и укажет на
`<slug>.localhost:4000` (браузеры резолвят `*.localhost` в 127.0.0.1), а песочница —
с `allow-same-origin`.

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
| POST | `/api/v1/markdown_images` | вход, multipart `image_file` |
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
| POST | `/api/v1/forum/topics/:id/read` | вход |
| PATCH | `/api/v1/forum/posts/:id` | автор или админ |
| DELETE | `/api/v1/forum/posts/:id` | админ |
| POST | `/api/v1/forum/posts/:id/reactions` | вход |
| GET | `/api/v1/forum/posts/:id/reactions` (`kind`) | публично |
| GET | `/api/v1/projects/:slug/forum/topics` | публично (черновик — владельцу) |
| POST | `/api/v1/projects/:slug/forum/topics` | вход |
| GET | `/api/v1/jams` (`phase`, `q`, `page`) | публично |
| GET | `/api/v1/jams/:slug` | публично (черновик — организатору) |
| POST | `/api/v1/jams` | вход, подтверждённая почта |
| PATCH | `/api/v1/jams/:slug` | организатор |
| DELETE | `/api/v1/jams/:slug` | организатор, только черновик |
| POST | `/api/v1/jams/:slug/publish` | организатор |
| POST | `/api/v1/jams/:slug/cancel` | организатор |
| POST | `/api/v1/jams/:slug/banner` | организатор, multipart `image_file` |
| POST | `/api/v1/jams/:slug/criteria` | организатор |
| PATCH | `/api/v1/jams/:slug/criteria/:id` | организатор |
| DELETE | `/api/v1/jams/:slug/criteria/:id` | организатор |
| GET | `/api/v1/jams/:slug/entries` (`page`, `sort`, `status=all`) | публично (снятые — организатору) |
| GET | `/api/v1/jams/:slug/eligible_projects` | вход |
| POST | `/api/v1/jams/:slug/entries` | вход, подтверждённая почта |
| DELETE | `/api/v1/jams/:slug/entries/:id` | автор до дедлайна, организатор |
| POST | `/api/v1/jams/:slug/entries/:id/disqualify` | организатор |
| POST | `/api/v1/jams/:slug/entries/:id/restore` | организатор |
| GET | `/api/v1/jams/:slug/scoring` | вход, подтверждённая почта |
| PUT | `/api/v1/jams/:slug/entries/:id/scores` | вход, подтверждённая почта |
| GET | `/api/v1/jams/:slug/entries/:id/feedback` | автор или организатор |
| GET | `/api/v1/jams/:slug/results` (`preview=true`) | публично (превью — организатору) |
| GET | `/api/v1/projects/:slug/jams` | публично |
| GET | `/api/v1/my_jams` | вход |
| GET | `/api/v1/users/:username` | публично |
| GET | `/api/v1/tags` (`q`, `limit`, `min_projects`) | публично |
| GET | `/api/v1/health` | публично |

Тема интерфейса хранится в `users.theme` для аккаунта и в cookie `isho_theme` для
устройства. Гость без сохранённого выбора видит тему системы; `data-theme` на
`<html>` выставляет Nuxt ещё на SSR, поэтому при загрузке нет вспышки.

Форум состоит из разделов (`forum_sections`), тем (`forum_topics`) и сообщений
(`forum_posts`). Разделы образуют два уровня: корневой раздел и подраздел
(`forum_sections.parent_id`). Адрес остаётся плоским (`/forum/:slug`), родитель нужен
для группировки, хлебных крошек и блока «Подразделы»; `group_title` — заголовок только
над корневыми разделами. Разделы создаются задачей `db.seed.required_data`; список
правится в `api/tasks/db/seed/forum_sections.cr`. Тема может быть привязана к проекту
(`forum_topics.project_id`) и тогда попадает в раздел `projects`. Тело темы — её первое
сообщение. Ответы и темы пишутся в Markdown и рендерятся на фронте тем же
`markdown-it`, что и дневники. Цитата хранит снимок автора и текста на момент ответа,
поэтому переживает редактирование или удаление оригинала.

Прочитанное хранится в `forum_topic_reads`: `read_count` — сколько сообщений темы
пользователь уже видел. Отсутствие строки значит, что тема не открывалась. Фронт
отмечает прочитанным последнее сообщение просмотренной страницы через
`POST /api/v1/forum/topics/:id/read`, поэтому открытие последней страницы закрывает
тему целиком. Автор последнего ответа денормализован в
`forum_topics.last_post_user_id` и показывается в списке тем.

Лайки и дизлайки лежат в `forum_post_reactions` (одна реакция на пользователя и
сообщение, `kind` — `like` или `dislike`). Счётчики не хранятся в сообщениях: их считает
`ForumReactions`, поэтому удаление пользователя или сообщения не оставляет мусора.
`POST /api/v1/forum/posts/:id/reactions` ставит голос, повторный клик снимает его, а
другой символ заменяет; за своё сообщение голосовать нельзя. Список проголосовавших для
попапа отдаёт `GET /api/v1/forum/posts/:id/reactions?kind=like|dislike` — последние 10
и признак `truncated`.

Администраторы (`users.is_admin`) могут удалять любые сообщения и темы; авторы
редактируют свои сообщения и название темы, но удалять их может только администратор.
Уведомлений об удалении пока нет. При удалении пользователя его темы и сообщения
удаляются: каскад в БД и операция `DeleteUserContent`, которая пересчитывает счётчики
тем. Почта удалённого аккаунта попадает в чёрный список и не может зарегистрироваться
снова, пока админ не уберёт её в окне модерации.

Вместо удаления администратор может забанить пользователя на срок с причиной. Контент
и публикации при этом остаются, а забаненный может войти и читать, но не может
создавать и править проекты, дневники и сообщения форума. История банов хранится
в `user_bans`, срок истекает сам; снять бан раньше можно кнопкой «Разбанить».

Джемы (`jams`) — отдельный раздел сайта `/jams`. У джема есть описание, правила,
призы, тема, баннер и три даты: старт, конец приёма заявок и конец судейства.
Черновик виден только организатору; публикация требует заполненных дат и хотя бы
одного критерия (`jam_criteria`). Фаза (`upcoming`, `open`, `judging`, `finished`,
`canceled`) вычисляется из дат, фоновых задач нет. В день старта тема перестаёт
скрываться. При публикации в одной транзакции создаётся раздел форума под корнем
`jams` (он же «Джемы»), а заголовок раздела следует за названием джема. Баннеры
хранятся через Latch (`media/jams/...`) и входят в квоту аккаунта.

Заявки (`jam_entries`) — это проекты. Один пользователь может подать несколько
проектов, но один проект входит в джем один раз. Подача доступна в фазе `open`;
проект должен быть опубликован и принадлежать автору. Отозвать заявку можно до
дедлайна, после — только организатор. Организатор снимает заявку с причиной и
возвращает её; снятые и скрытые проекты не попадают в публичный список и счётчик,
но видны автору и организатору. На странице проекта есть блок «Участие в джемах».

Оценки (`jam_scores`) — балл и текстовый отзыв по каждому критерию. Голосовать может
любой подтверждённый пользователь, кроме своей заявки и только в фазе `judging`.
Режим `community` считает баллы всех, `participants` — только тех, у кого есть
поданная заявка; остальные голоса всё равно приносят автору отзывы. После первой
оценки критерии, шкала, режим и даты фиксируются. После судейства `JamResults`
автоматически считает средневзвешенные суммы, места (равные итоги делят место) и
счётчики. Публично видны агрегаты и места, автор заявки получает анонимные отзывы
по критериям, организатор — те же отзывы с именами. Победителей администратор пишет
в `results_note` — это отдельный текст, а не вычисленное место.

## Production

Готовые скрипты лежат в `deploy/` (подробности — `deploy/README.md`). Сборка идёт
локально в WSL (Ubuntu 24.04), на сервер уезжают только release-бинарники Lucky
и серверный бандл Nuxt:

```powershell
$env:ISHO_SSH_PASSWORD = '<пароль root>'
.\deploy\deploy.ps1                       # собрать и раскатать, http://<ip>
.\deploy\deploy.ps1 -SampleData           # плюс демо-проекты и demo@isho.local
.\deploy\deploy.ps1 -SiteAddress https://isho.duckdns.org   # домен + TLS
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

Браузерные сборки живут на отдельных origin'ах: база `-MediaAddress
https://isho-games.duckdns.org` и у каждого проекта свой хост
`<slug>.isho-games.duckdns.org` (Caddy отдаёт на них только `/media/web/*`). Игра в
песочнице сохраняет свой origin и поэтому может пользоваться Cache Storage, IndexedDB
и localStorage, которых opaque origin не даёт, — а cookie сайта на эти хосты не
отправляются. Один origin на проект: сейвы и кеш игр не смешиваются, а все сборки
проекта делят хост, так что прогресс переживает обновление версии. База — отдельное
имя, а не поддомен сайта: поддомен делит registrable domain и может ставить cookie на
родителя. Сертификаты проектных хостов выдаются on-demand, Caddy спрашивает API
(`/internal/tls/allow`). Сжатые файлы Unity (`.br`, `.gz`) уходят с `Content-Encoding`
и типом исходного файла, иначе `nosniff` не даёт загрузить framework.

## Ограничения прототипа

- Скачиваемые файлы не загружаются: только внешние https-ссылки (Google Drive, Dropbox и т.п.).
- Скриншоты: JPEG/PNG/WebP до 10 МБ, до 20 на проект.
- Публикация проектов без модерации; черновики видны только владельцу.
- Проект можно пометить как 18+ и указать использование ИИ (без ИИ, частичное,
  значительное, полное). Гости не видят 18+; в `/settings` пользователь скрывает такие
  проекты и ограничивает показ по уровню ИИ. Владелец и администратор видят всё.
- Описания проектов, дневники и форум — Markdown (`markdown-it`, сырой HTML отключён):
  изображения, Rutube-видео через `![alt](https://rutube.ru/video/<id>/)`, спойлеры
  `:::spoiler` … `:::` и подсветка кода. Картинку можно вставить из буфера обмена,
  перетащить в редактор или загрузить файлом (PNG/JPEG/WebP/GIF до 10 МБ): редактор
  загружает её через `POST /api/v1/markdown_images` и вставляет обычную ссылку
  `![alt](/media/...)`. Загруженные, но так и не вставленные в сохранённый текст
  картинки удаляет задача `db.cleanup_markdown_images` (по умолчанию — старше 7 дней,
  без `--yes` работает как сухой прогон). Короткие записи дневника (до 600 символов)
  показываются на странице проекта целиком, длинные — отдельной страницей со ссылкой из ленты.
- Форум: без вложений, уведомлений, закрепления и закрытия тем, поиска и rate limit.
  Удаление сообщений и тем — только администраторами.
- Джемы: страница, правила, критерии, баннер, публикация, раздел форума, заявки
  проектами, оценки с отзывами, автоматические итоги и места.
- Оплаты, S3, ресурсы, номинации и приз зрительских симпатий — следующие этапы.
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

## Стресс-тест

Проверка на объёме: 1000 пользователей, 1000 проектов, 1000 тегов, 1000 тем
форума и по 200 сообщений в каждой. Данные создаются и удаляются задачами
`db.stress.seed` / `db.stress.cleanup`, а `stress/probe.mjs` замеряет API и SSR.
Подробности и команды для VPS — в [stress/README.md](stress/README.md).


