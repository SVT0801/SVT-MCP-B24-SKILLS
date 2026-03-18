# b24-skills для Claude Code

Скилы для настройки и работы с Bitrix24 через Claude Code (VS Code).

## Установка

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/SVT0801/SVT-MCP-B24-SKILLS/main/dist/install.sh)
```

Скрипт покажет экран приветствия, запросит ключ и загрузит ZIP-архивы скилов в папку:
```
~/Downloads/b24-skills_ДАТА_ВРЕМЯ/
```

### После загрузки

Папка появится в Finder → `~/Downloads/b24-skills_...`
В папке — ZIP-файл по каждому скилу и `README.txt` с инструкцией.

**Для Claude.ai (браузер / десктоп-приложение):**
1. Открой claude.ai → нажми на аватар → **Settings**
2. Раздел **Skills** (или **Profile**)
3. Загрузи каждый `.zip` файл через UI
4. Открой новый чат — скилы доступны

**Для Claude Code CLI или VS Code + GitHub Copilot:**
Распакуй ZIP-файлы в `~/.claude/skills/user/` (глобально) или в `.claude/skills/` внутри проекта.

## Обновление

Та же команда с тем же ключом — загрузит обновлённые ZIP в новую папку с текущей датой.

## Что входит

- **b24-config** — мастер настройки Bitrix24: CRM, задачи, проекты, звонки
- **b24-config-crm-*** — отдельные конфигураторы CRM-сущностей
- **b24-setup-rules** — правила работы с порталом
- **b24-skill-create** — создание новых скилов

## Получить ключ

[→ ссылка на покупку]
