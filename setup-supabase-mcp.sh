#!/bin/bash

# =============================================================
# setup-supabase-mcp.sh
# Установка / Удаление Supabase MCP в Claude Desktop
# Устанавливает доступ только к одному выбранному проекту
# Не затрагивает другие MCP серверы
# =============================================================

CONFIG_DIR="$HOME/Library/Application Support/Claude"
CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║   Claude Desktop + Supabase MCP Setup     ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────────
# МЕНЮ
# ─────────────────────────────────────────────
echo "  Что нужно сделать?"
echo ""
echo "  1. Установить  — добавить Supabase MCP для конкретного проекта"
echo "  2. Удалить     — убрать Supabase MCP (другие серверы не затрагиваются)"
echo ""
read -p "  Выбери действие (1 или 2): " ACTION
echo ""

if [ "$ACTION" = "2" ]; then

  # ═══════════════════════════════════════════
  # УДАЛЕНИЕ
  # ═══════════════════════════════════════════

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Файл конфига не найден: $CONFIG_FILE"
    exit 1
  fi

  # Находим только серверы установленные этим скриптом (mcp-remote + mcp.supabase.com)
  MANAGED_SERVERS=$(python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
servers = data.get('mcpServers', {})
found = []
for name, cfg in servers.items():
    args = cfg.get('args', [])
    if 'mcp-remote' in args:
        url = next((a for a in args if 'mcp.supabase.com' in a), '')
        if url:
            found.append(name + '|' + url)
for i, s in enumerate(found, 1):
    print(str(i) + '|' + s)
" 2>/dev/null)

  if [ -z "$MANAGED_SERVERS" ]; then
    echo "⚠️  Нет серверов установленных этим скриптом — удалять нечего"
    echo ""
    echo "   Все серверы в конфиге (не управляются этим скриптом):"
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
for name in data.get('mcpServers', {}):
    print(f'   • {name}')
" 2>/dev/null
    exit 0
  fi

  echo "  Серверы Supabase установленные этим скриптом:"
  echo ""
  echo "$MANAGED_SERVERS" | while IFS='|' read -r num name url; do
    echo "  $num. $name"
    echo "     $url"
    echo ""
  done

  SERVER_COUNT=$(echo "$MANAGED_SERVERS" | wc -l | tr -d ' ')
  read -p "Введи номер сервера для удаления (1-$SERVER_COUNT): " DEL_NUM

  if ! [[ "$DEL_NUM" =~ ^[0-9]+$ ]] || [ "$DEL_NUM" -lt 1 ] || [ "$DEL_NUM" -gt "$SERVER_COUNT" ]; then
    echo "❌ Неверный номер"
    exit 1
  fi

  SERVER_NAME=$(echo "$MANAGED_SERVERS" | awk -F'|' -v n="$DEL_NUM" 'NR==n {print $2}')

  echo ""
  echo "▶ Удаляю '$SERVER_NAME' из конфига Claude Desktop..."
  echo "  Конфиг: $CONFIG_FILE"
  echo ""

  # Бэкап
  BACKUP_FILE="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
  cp "$CONFIG_FILE" "$BACKUP_FILE"
  echo "✅ Бэкап сохранён:"
  echo "   $BACKUP_FILE"
  echo ""

  # Показать что есть сейчас
  echo "   Серверы до удаления:"
  python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
for name in data.get('mcpServers', {}):
    tag = '  ← будет удалён' if name == '$SERVER_NAME' else ''
    print(f'   • {name}{tag}')
" 2>/dev/null
  echo ""

  # Удаляем только выбранный
  python3 << DELEOF
import json

with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)

config.get('mcpServers', {}).pop('$SERVER_NAME', None)

with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
DELEOF

  # Валидация
  if ! python3 -m json.tool "$CONFIG_FILE" > /dev/null 2>&1; then
    echo "❌ Ошибка в JSON — восстанавливаю бэкап"
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    exit 1
  fi

  echo "✅ '$SERVER_NAME' удалён. Остальные серверы сохранены."
  echo ""
  echo "   Серверы после удаления:"
  python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
servers = data.get('mcpServers', {})
if servers:
    for name in servers:
        print(f'   • {name}')
else:
    print('   (нет серверов)')
" 2>/dev/null

  echo ""
  echo "▶ Перезапускаю Claude Desktop..."
  osascript -e 'quit app "Claude"' 2>/dev/null
  sleep 3
  open -a "Claude" 2>/dev/null

  echo ""
  echo "╔════════════════════════════════════════════╗"
  echo "║          ✅ '$SERVER_NAME' удалён            ║"
  echo "╚════════════════════════════════════════════╝"
  echo ""
  echo "  Бэкап исходного конфига:"
  echo "  $BACKUP_FILE"
  echo ""
  exit 0
fi

if [ "$ACTION" != "1" ]; then
  echo "❌ Неверный выбор. Введи 1 или 2."
  exit 1
fi

# ═══════════════════════════════════════════
# УСТАНОВКА
# ═══════════════════════════════════════════

# ─────────────────────────────────────────────
# ШАГ 1 — Получить MCP URL проекта
# ─────────────────────────────────────────────
echo "─────────────────────────────────────────────"
echo "  Нужен MCP URL твоего Supabase проекта"
echo "─────────────────────────────────────────────"
echo "  1. Открой: https://supabase.com → выбери проект"
echo "  2. Нажми кнопку Connect (сверху)"
echo "  3. Перейди в раздел: App Frameworks → MCP"
echo "  4. Скопируй URL вида:"
echo "     https://mcp.supabase.com/mcp?project_ref=XXXXX"
echo "     (или всю команду claude mcp add ... — тоже подойдёт)"
echo "─────────────────────────────────────────────"
echo ""
read -p "Вставь URL или команду: " MCP_INPUT

if [ -z "$MCP_INPUT" ]; then
  echo "❌ Поле не может быть пустым"
  exit 1
fi

# Извлекаем URL из вставленного (принимаем как URL, так и команду claude mcp add)
MCP_URL=$(echo "$MCP_INPUT" | grep -oE 'https://mcp\.supabase\.com/mcp\?project_ref=[a-zA-Z0-9]+')

if [ -z "$MCP_URL" ]; then
  echo "❌ Не удалось найти MCP URL"
  echo "   Ожидаемый формат: https://mcp.supabase.com/mcp?project_ref=xxxxxxxx"
  exit 1
fi

PROJECT_REF=$(echo "$MCP_URL" | grep -oE 'project_ref=[a-zA-Z0-9]+' | cut -d'=' -f2)

# Пробуем получить название проекта без авторизации
echo ""
echo "▶ Определяю название проекта..."
PROJECT_NAME=$(curl -s \
  "https://api.supabase.com/v1/projects/$PROJECT_REF" \
  -H "Authorization: Bearer invalid" 2>/dev/null | \
  python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('name', ''))
except:
    print('')
" 2>/dev/null)

# Фолбек на project_ref если имя не получили
SUGGESTED_NAME="${PROJECT_NAME:-$PROJECT_REF}"
echo "✅ MCP URL : $MCP_URL"
echo ""
read -p "Имя сервера в Claude Desktop [$SUGGESTED_NAME]: " SERVER_NAME
SERVER_NAME="${SERVER_NAME:-$SUGGESTED_NAME}"

echo ""
echo "✅ Project ref: $PROJECT_REF"
echo "✅ Имя сервера: $SERVER_NAME"

# ─────────────────────────────────────────────
# ШАГ 2 — Обновляем конфиг (mcp-remote + OAuth, токен не нужен)
# ─────────────────────────────────────────────
echo ""
echo "▶ Обновляю конфиг Claude Desktop..."
echo "  Конфиг: $CONFIG_FILE"

mkdir -p "$CONFIG_DIR"

BACKUP_FILE="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"

if [ -f "$CONFIG_FILE" ]; then
  cp "$CONFIG_FILE" "$BACKUP_FILE"
  echo ""
  echo "✅ Бэкап сохранён:"
  echo "   $BACKUP_FILE"

  echo ""
  echo "   Существующие серверы (будут сохранены):"
  python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
for name in data.get('mcpServers', {}):
    print(f'   • {name}')
" 2>/dev/null
  echo ""

  # Мерж — используем mcp-remote для OAuth (токен не хранится в конфиге)
  MCP_URL="$MCP_URL" SERVER_NAME="$SERVER_NAME" CONFIG_FILE="$CONFIG_FILE" python3 << 'MERGEEOF'
import json, os

mcp_url     = os.environ['MCP_URL']
server_name = os.environ['SERVER_NAME']
config_file = os.environ['CONFIG_FILE']

with open(config_file, 'r') as f:
    config = json.load(f)

if 'mcpServers' not in config:
    config['mcpServers'] = {}

config['mcpServers'][server_name] = {
    "command": "npx",
    "args": [
        "mcp-remote",
        mcp_url
    ]
}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
MERGEEOF

  echo "✅ '$SERVER_NAME' добавлен (только проект: $PROJECT_REF)"
  echo "   Токен в конфиге НЕ хранится — аутентификация через браузер."
  echo "   Остальные серверы сохранены."

else
  echo "   Конфиг не найден — создаю новый..."
  MCP_URL="$MCP_URL" SERVER_NAME="$SERVER_NAME" CONFIG_FILE="$CONFIG_FILE" python3 << 'NEWEOF'
import json, os

config = {
    "mcpServers": {
        os.environ['SERVER_NAME']: {
            "command": "npx",
            "args": [
                "mcp-remote",
                os.environ['MCP_URL']
            ]
        }
    }
}

with open(os.environ['CONFIG_FILE'], 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
NEWEOF
  echo "✅ Новый конфиг создан"
fi

# ─────────────────────────────────────────────
# ШАГ 4 — Валидация итогового JSON
# ─────────────────────────────────────────────
echo ""
echo "▶ Проверяю итоговый конфиг..."

if python3 -m json.tool "$CONFIG_FILE" > /dev/null 2>&1; then
  echo "✅ JSON валидный"
  echo ""
  echo "   Итоговые MCP серверы:"
  python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
for name in data.get('mcpServers', {}):
    tag = '  ← добавлен' if name == '$SERVER_NAME' else ''
    print(f'   • {name}{tag}')
"
else
  echo "❌ Ошибка в JSON — восстанавливаю бэкап"
  [ -f "$BACKUP_FILE" ] && cp "$BACKUP_FILE" "$CONFIG_FILE"
  exit 1
fi

# ─────────────────────────────────────────────
# ШАГ 5 — Перезапуск Claude Desktop
# ─────────────────────────────────────────────
echo ""
echo "▶ Перезапускаю Claude Desktop..."
osascript -e 'quit app "Claude"' 2>/dev/null
sleep 3
open -a "Claude" 2>/dev/null

# ─────────────────────────────────────────────
# ИТОГ
# ─────────────────────────────────────────────
echo ""
echo "╔════════════════════════════════════════════╗"
echo "║              ✅ ГОТОВО                     ║"
echo "╚════════════════════════════════════════════╝"
echo ""
  echo "  Имя сервера      : $SERVER_NAME"
  echo "  Подключён проект : $PROJECT_REF"
  echo "  Доступ           : только этот проект (OAuth через браузер)"
echo ""
echo "  Бэкап исходного конфига:"
echo "  $BACKUP_FILE"
echo ""
  echo "  Проверь в Claude Desktop:"
  echo "  молоток → в списке должен быть '$SERVER_NAME'"
echo ""
