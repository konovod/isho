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
| Caddy (Ubuntu `caddy` 2.6) | `/etc/caddy/Caddyfile`, `caddy.service`, порты 80/443 |

Caddy раздаёт всё с одного origin: `/api/*` и `/media/*` идут в Lucky, остальное — в Nuxt.
Скриншоты лежат в `/srv/isho/api/public/media` (Latch, файловое хранилище).

## Первый деплой

```powershell
$env:ISHO_SSH_PASSWORD = '<пароль root>'
.\deploy\deploy.ps1
```

Без `-SiteAddress` сайт открывается по `http://<ip>`: Caddy слушает `:80`,
`COOKIE_SECURE=false`, `APP_ORIGIN=http://<ip>`.

Пароль можно не передавать через переменную — скрипт спросит его сам.

## Домен и HTTPS

Когда A-запись домена указывает на IP сервера:

```powershell
.\deploy\deploy.ps1 -SiteAddress https://vm4775508.firstbyte.club
```

Тогда Caddy получает сертификат Let's Encrypt автоматически, а `APP_ORIGIN`,
`APP_DOMAIN` и `COOKIE_SECURE=true` обновляются в `/etc/isho/api.env`.
Повторный запуск с `-SkipBuild` переустановит только конфиг и рестартует службы
(артефакт берётся из `deploy/artifacts/isho-deploy.tar.gz`).

## Демо-данные

По умолчанию создаются только обязательные данные (разделы форума).
С демо-проектами и аккаунтами:

```powershell
.\deploy\deploy.ps1 -SampleData
```

После сида доступен демо-аккаунт `demo@isho.local` / `password1234`.

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
