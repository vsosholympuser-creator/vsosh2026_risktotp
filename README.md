# RiskTOTP — MFA (TOTP) для SSH и критичных админ-операций в Linux

**Направление:** Blue Team  
**Форма продукта:** программный комплекс (PAM + утилиты-обёртки + AppArmor + аудит)

## Коротко о проекте
RiskTOTP добавляет **второй фактор (TOTP)** не только на вход по SSH, но и на выполнение **критичных операций администрирования**.  
Даже если злоумышленник получил валидные данные оператора (пароль/SSH-ключ), ему требуется TOTP, а попытки перебора ограничиваются и логируются.

### Защита
- SSH-доступ (через PAM + TOTP)
- смена паролей пользователей (`secure-passwd`)
- управление SSH-ключами пользователей (`secure-sshkeys`)
- ограниченный набор операций `useradd/usermod` (`secure-admin`)
- (опционально) подтверждение CRITICAL-операций вторым оператором (`secure-approve`)

## Модель угроз (ограничения)
Предполагается, что злоумышленник может получить валидные учётные данные оператора (пароль/SSH-ключ), но:
- не имеет root-доступа;
- не использует CVE для обхода механизмов TOTP/AppArmor;
- не имеет прямого доступа к TOTP-секретам пользователей;
- сценарии фишинга/кейлоггеров/кражи кодов рассматриваются как внешние ограничения.

## Роли и политика доступа
- **root:** не ограничивается проектом (root может отключить защиту).
- **operators:** запускают только `secure-*` через `sudo` (по sudoers).  
  Прямой запуск исходных `passwd/usermod/useradd` запрещён политикой (sudoers + AppArmor).
- **users:** не имеют доступа к `secure-*`.

## Компоненты
- **PAM + TOTP (SSH):** `google-authenticator-libpam`
- **secure-passwd:** `sudo secure-passwd <user>`
- **secure-sshkeys:** `sudo secure-sshkeys <user> add/remove/add-file/remove-file <key|path>`
- **secure-admin:** `sudo secure-admin useradd ...` / `sudo secure-admin usermod ...`
- **secure-audit-view:** просмотр аудита
- **AppArmor профили:** `/etc/apparmor.d/usr.local.sbin.secure-*`
- **SQLite:** `/var/lib/risktotp/secure_totp.db` (счётчик попыток и блокировки)
- **Audit log:** `/var/log/risktotp/audit.log` (JSONLines)

---

# Установка

## Требования
- Debian/Kali/Ubuntu с AppArmor
- `sudo`
- Python 3
- Пакеты: `apparmor`, `apparmor-utils`, `sqlite3`, `python3-pyotp`

## Быстрая установка (рекомендуется)
`sudo bash install.sh`
Скрипт:

* копирует бинарники/скрипты в `/usr/local/sbin/`
* настраивает группу `operators`
* устанавливает sudoers в `/etc/sudoers.d/operators`
* устанавливает/включает AppArmor и применяет профили
* создаёт каталоги `/var/lib/risktotp` и `/var/log/risktotp`

> Важно: перед использованием добавьте операторов в группу `operators`.

---

# Настройка TOTP

## 1) Для SSH (PAM)

1. Установите модуль:

`sudo apt install libpam-google-authenticator`

2. Для пользователя, который входит по SSH:

`google-authenticator`

3. Включите в PAM sshd (пример, может отличаться по дистрибутиву):
   `/etc/pam.d/sshd`:

>auth required pam_google_authenticator.so nullok
>@include common-auth

4. Перезапустите SSH:

`sudo systemctl restart ssh`

## 2) Для операторов (secure-*)

У каждого оператора должен существовать файл:
`/home/<operator>/.google_authenticator`

---

# Использование

## secure-passwd

Смена пароля пользователя с подтверждением TOTP оператора:

`sudo secure-passwd <user>`

## secure-sshkeys

Добавить ключ строкой:

`sudo secure-sshkeys <user> add "ssh-ed25519 AAAA... comment"`

Добавить ключ из файла:

`sudo secure-sshkeys <user> add-file /tmp/key.pub`

Удалить ключ строкой:

`sudo secure-sshkeys <user> remove "ssh-ed25519 AAAA... comment"`

Удалить ключ из файла:

`sudo secure-sshkeys <user> remove-file /tmp/key.pub`

## secure-admin

Примеры:

`sudo secure-admin useradd <new_user>`
`sudo secure-admin usermod lock <user>`
`sudo secure-admin usermod add-groups <user> operators`

## Просмотр аудита

Примеры:

`sudo secure-audit-view --tail 50`
`sudo secure-audit-view --approvals`
`sudo secure-audit-view --id 4`
`sudo secure-audit-view --verify`

---

# Аудит и анти-брут

* Каждая попытка подтверждения логируется в /var/log/risktotp/audit.log
* Для каждого оператора ведётся счётчик неверных TOTP-попыток в SQLite
* При достижении лимита попыток ввод блокируется на заданное время
* При ошибке добавляется задержка (анти-брут)

---

# Демонстрация (рекомендуемый сценарий)

1. SSH вход: запрос пароля и TOTP.
2. secure-passwd: смена пароля пользователю (TOTP + лог).
3. secure-sshkeys add-file: добавление ключа (TOTP + лог).
4. secure-admin usermod add-groups: управление группами (TOTP + лог).
5. (опционально) CRITICAL approve: заявка → подтверждение → выполнение → цепочка логов.

---

# Ограничения

* Root может отключить защиту — root не рассматривается как ограничиваемая роль.
* Не рассматриваются кейлоггеры/фишинг/кража TOTP-секретов.
* Не учитываются уязвимости (CVE) и эскалация привилегий.

---
