# Деплой isho

Скрипты в этой папке собирают проект локально в WSL (Ubuntu 24.04 — та же версия,
что и на сервере) и раскатывают готовые артефакты на сервер. На сервере не нужен
Crystal и не нужна сборка: туда уезжают только release-бинарник Lucky и готовый
серверный бандл Nuxt.

## Что ставится на сервере

| Компонент | Где |
|---|---|
| PostgreSQL 16 | `postgresql.service`, БД `isho_production`, роль `isho` |
| Lucky API | `/srv/isho/api`, `isho-api.service`, `127.0.0.1:4000` |
| Nuxt SSR | `/srv/isho/web`, `isho-web.service`, `127.0.0.1:3000` |
| Caddy (официальная сборка 2.11, `/usr/local/bin/caddy`) | `/etc/caddy/Caddyfile`, `caddy.service`, порты 80/443 |
| Сборки | `/srv/isho/api/public/media/build` и `/media/web`, `isho-storage.timer` |

Caddy раздаёт всё с одного origin: `/api/*` и `/media/*` идут в Lucky, остальное — в Nuxt.
Скриншоты лежат в `/srv/isho/api/public/media` (Latch, файловое хранилище).

## Первый деплой

```powershell
$env:ISHO_SSH_PASSWORD = '<пароль root>'
.\deploy\deploy.ps1
```

Без `-SiteAddress` сайт открывается по `http://<ip>`: Caddy слушает `:80`,
`COOKIE_SECURE=false`, `APP_ORIGIN=http://<ip>`. `APP_ORIGIN` и `APP_DOMAIN`
выводятся из `-SiteAddress`, поэтому расхождение между ними — ошибка деплоя:
API сверяет заголовок `Origin` с `APP_ORIGIN` и берёт из того же значения флаг
`Secure` у cookie.

Пароль можно не передавать через переменную — скрипт спросит его сам.

## Домен и HTTPS

Когда A-запись домена указывает на IP сервера, достаточно одного флага:

```powershell
.\deploy\deploy.ps1 -SiteAddress https://isho.duckdns.org
```

Тогда Caddy получает сертификат Let's Encrypt автоматически, а `APP_ORIGIN`,
`APP_DOMAIN` и `COOKIE_SECURE=true` обновляются в `/etc/isho/api.env`.
Повторный запуск с `-SkipBuild` переустановит только конфиг и рестартует службы
(артефакт берётся из `deploy/artifacts/isho-deploy.tar.gz`).

Сертификаты Caddy хранит в `/var/lib/caddy` (файловое хранилище в Caddyfile),
так что ни рестарт, ни повторный деплой не приводят к новому выпуску: у Let's
Encrypt на одно имя действует лимит в 5 сертификатов в неделю.

### DuckDNS: бесплатное имя

`isho.duckdns.org` уже указывает на сервер. Если запись надо обновить прямо из
деплоя (например, сменился IP), возьмите токен на duckdns.org и передайте его:

```powershell
$env:ISHO_DUCKDNS_TOKEN = '<токен>'
.\deploy\deploy.ps1 -SiteAddress https://isho.duckdns.org -SkipBuild
```

Скрипт вызовет API DuckDNS и направит `<имя>.duckdns.org` на `-Server`. Домен
`duckdns.org` есть в Public Suffix List, поэтому лимит Let's Encrypt (50
сертификатов в неделю на зарегистрированный домен) считается отдельно для
`isho.duckdns.org` и ни с кем не делится.

### Без домена: nip.io

`185-180-231-183.nip.io` резолвится в `185.180.231.183` сам, без регистрации:

```powershell
.\deploy\deploy.ps1 -SiteAddress https://185-180-231-183.nip.io
```

Для постоянной витрины это плохой вариант: `nip.io` нет в Public Suffix List,
поэтому для Let's Encrypt зарегистрированный домен — сам `nip.io`, и лимит в 50
сертификатов в неделю общий для всех его пользователей. Первый выпуск может
упасть с `too many certificates already issued for "nip.io"` — Caddy повторяет
попытки сам, но ждать придётся часами (лимит пополняется на один сертификат
каждые ~3.4 часа). Продление того же имени под этот лимит не попадает, зато
имя завязано на IP: смена IP — новое имя и новый сертификат.

## Демо-данные

По умолчанию создаются только обязательные данные (разделы форума).
С демо-проектами и аккаунтами:

```powershell
.\deploy\deploy.ps1 -SampleData
```

После сида доступен демо-аккаунт `demo@isho.local` / `password1234`.

## Почта и подтверждение адреса

Регистрация отправляет письмо со ссылкой `/confirm_email?token=...`, а публикация
проектов и сообщения на форуме доступны только после подтверждения. Транспорт
выбирается переменной `MAIL_ADAPTER` в `/etc/isho/api.env`:

| `MAIL_ADAPTER` | Что делает |
|---|---|
| `smtp` | шлёт через SMTP (`SMTP_HOST`, `SMTP_PORT`, `SMTP_TLS`, `SMTP_USER`, `SMTP_PASSWORD`) |
| `sendgrid` | SendGrid HTTP API, нужен `SEND_GRID_KEY` |
| `dev` | печатает письма в journal вместо отправки |

`MAIL_FROM` — адрес отправителя. Первый деплой с почтой (mail.ru, TLS 465):

```powershell
$env:ISHO_SMTP_PASSWORD = 'пароль-приложения'   # не сам пароль от ящика
.\deploy\deploy.ps1 -SiteAddress https://example.com -MailFrom isho2026@mail.ru
```

Без `-MailFrom` деплой ставит `MAIL_ADAPTER=dev` и `EMAIL_CONFIRMATION=off`,
чтобы никто не остался без возможности публиковать. Значения в
`/etc/isho/api.env` пишутся только при первом деплое, дальше они — источник
истины: их можно править на сервере, и следующий деплой их не перезапишет.

Пароль приложения для mail.ru: Настройки → Безопасность → Пароли для внешних
приложений (обычный пароль от ящика не подойдёт). Свежий ящик mail.ru первое
время отклоняет письма на внешние адреса с `550 non-local recipient
verification failed` — нужно подтвердить телефон/включить отправку на внешние
адреса в настройках ящика, иначе письма будут доходить только до `@mail.ru`.
Если ящик так и не разблокируют, подойдёт любой SMTP-провайдер (Brevo, Mailjet,
Unisender Go) — меняются только `SMTP_*` и `MAIL_FROM`.

Полезные команды на сервере:

```bash
sudo -u isho -H bash -c 'set -a; . /etc/isho/api.env; set +a; cd /srv/isho/api && ./bin/tasks db.confirm_email <email>'
journalctl -u isho-api -f          # письма в режиме dev видны здесь
```

## ИИ на форуме

Ответ на новую тему, подсказка раздела и флеир автора работают через DeepSeek.
Ключ передаётся при деплое и остаётся только в `/etc/isho/api.env`:

```powershell
$env:ISHO_AI_API_KEY = 'sk-...'
.\deploy\deploy.ps1 -SiteAddress https://example.com
```

Повторный деплой с ключом заменяет его (`-AiApiKey` или `ISHO_AI_API_KEY`), а без
ключа оставляет прежний. Пока ключа нет, все ИИ-функции выключены: галочка в форме
не показывается, воркер ничего не делает. `AI_ENABLED=off` выключает их при живом
ключе. Модель и потолок трат настраиваются там же:

```bash
AI_MODEL=deepseek-chat
AI_DAILY_JOBS=200
AI_DAILY_INPUT_TOKENS=1500000
AI_DAILY_OUTPUT_TOKENS=300000
```

Задачи разбирает отдельный сервис `isho-ai` (юнит `deploy/server/isho-ai.service`).
Он сам обновляет флеиры активных авторов и чистит старые записи. Наблюдение и чистка:

```bash
sudo -u isho -H bash -c 'set -a; . /etc/isho/api.env; set +a; cd /srv/isho/api && ./bin/tasks ai.stats'
sudo -u isho -H bash -c 'set -a; . /etc/isho/api.env; set +a; cd /srv/isho/api && ./bin/tasks ai.clear_flair <email или ник>'
journalctl -u isho-ai -f
```

Пределы: 3 ответа в сутки на аккаунт (и не раньше 3 дней и 5 сообщений), 10 подсказок
раздела в час и 30 в сутки, флеир не чаще раза в 24 часа. Общий дневной потолок
считается по всем аккаунтам; после него воркер спит до полуночи UTC. Лимит трат лучше
продублировать в кабинете DeepSeek — это последний рубеж.

## Сборки и место на диске

Авторы выкладывают файлы для скачивания и веб-сборки (ZIP с `index.html`). Файлы
приезжают кусками по 8 МБ в `POST /api/v1/projects/:slug/uploads`, готовый файл
уезжает в `/srv/isho/api/public/media/build`, а распакованная игра — в
`/srv/isho/api/public/media/web/<uuid>`. Скачивание отдаёт Lucky с поддержкой
`Range`, поэтому большие архивы докачиваются.

Лимиты по умолчанию: 300 МБ на сборки проекта, 1 ГБ на аккаунт (сборки,
скриншоты и картинки в Markdown) и 12 ГБ на сервер. Загрузки не трогают
последние 2 ГБ диска: это резерв для ОС, Postgres, логов и свопа. Значения
можно поменять в `/etc/isho/api.env` — они читаются на каждом запросе, без
пересборки:

```bash
STORAGE_PROJECT_LIMIT_BYTES=300000000
STORAGE_ACCOUNT_LIMIT_BYTES=1000000000
STORAGE_SERVER_LIMIT_BYTES=12000000000
STORAGE_RESERVE_BYTES=2000000000
```

`isho-storage.timer` раз в сутки запускает `tasks storage.cleanup --yes` и пишет
отчёт в journal. Вручную:

```bash
sudo -u isho -H bash -c 'set -a; . /etc/isho/api.env; set +a; cd /srv/isho/api && ./bin/tasks storage.stats'
sudo -u isho -H bash -c 'set -a; . /etc/isho/api.env; set +a; cd /srv/isho/api && ./bin/tasks storage.cleanup'
```

Веб-сборки отдаются с `Content-Security-Policy: sandbox` без `allow-same-origin`:
игра не может читать куки и обращаться к API от имени посетителя. Плата за это —
только относительные пути и отсутствие `localStorage` и `SharedArrayBuffer`.
Файлы для скачивания отдаются с `Content-Disposition: attachment`.

## Полезное на сервере

```bash
systemctl status isho-api isho-web caddy
journalctl -u isho-api -f
sudo -u isho -H bash -c 'set -a; . /etc/isho/api.env; set +a; cd /srv/isho/api && ./bin/tasks db.make_admin <email>'
```

Секреты (пароль БД, `SECRET_KEY_BASE`) лежат в `/etc/isho/api.env` и при повторных
деплоях не перегенерируются.

## Часовой пояс

`bootstrap.sh` ставит серверу `Europe/Moscow`: `useFormat()` форматирует даты в
локальной зоне, и так SSR и браузер показывают одно и то же время (демо-данные
тоже написаны для МСК). Если аудитория в другой зоне, лучше задать `timeZone`
явно в `web/app/composables/useFormat.ts`.

## Ограничения

- Сборка идёт на машине разработчика в WSL; нужны интернет и `wsl -u root`.
- Сервер на 709 МБ RAM: включён swap-файл 1 ГБ, Node ограничен
  `--max-old-space-size=320`. Хватает на прототип, но не на нагрузку.
