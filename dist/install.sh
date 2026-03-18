#!/usr/bin/env bash
# =============================================================
# install.sh — установка b24-skills в Claude Code / VS Code
# Использование: bash install.sh
# =============================================================

set -euo pipefail

SUPABASE_URL="https://izfirrsivyfkwjefztlx.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml6ZmlycnNpdnlma3dqZWZ6dGx4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4MDQ2NzUsImV4cCI6MjA4OTM4MDY3NX0.uDGUlWsecO9pyFytT57ydSRWcslhFONCllZsfoLSq1E"
BUCKET="skills"

# ─────────────────────────────────────────
# Экран приветствия
# ─────────────────────────────────────────
clear 2>/dev/null || true
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                                                          ║"
echo "║           b24-skills для Claude Code                    ║"
echo "║                                                          ║"
echo "║   Скилы для настройки и работы с Bitrix24               ║"
echo "║   через Claude Code (VS Code)                           ║"
echo "║                                                          ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║                                                          ║"
echo "║   Что входит:                                            ║"
echo "║   • b24-config         — мастер настройки портала       ║"
echo "║   • b24-config-crm-*   — CRM: сделки, лиды, контакты   ║"
echo "║   • b24-config-tasks   — задачи и проекты               ║"
echo "║   • b24-config-calls   — звонки и телефония             ║"
echo "║   • b24-setup-rules    — правила работы с порталом      ║"
echo "║   • b24-skill-create   — создание новых скилов          ║"
echo "║                                                          ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║                                                          ║"
echo "║   Разработчик: SVT  |  @svyat_b24                       ║"
echo "║   GitHub: github.com/SVT0801/SVT-MCP-B24-SKILLS         ║"
echo "║                                                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────
# Меню
# ─────────────────────────────────────────
printf "  [1] Установить / обновить скилы\n"
printf "  [q] Выйти\n"
echo ""
printf "  Выбор: "
read -r MENU_CHOICE

echo ""
[[ "$MENU_CHOICE" == "q" || -z "$MENU_CHOICE" ]] && echo "  Выход." && exit 0

if [[ "$MENU_CHOICE" != "1" ]]; then
  echo "  Неверный выбор. Выход."
  exit 1
fi

# ─────────────────────────────────────────
# Запрос ключа
# ─────────────────────────────────────────
echo "  Введи ключ доступа:"
printf "  Ключ: "
read -r KEY

echo ""

if [[ -z "$KEY" ]]; then
  echo "  ❌ Ключ не введён."
  exit 1
fi

echo "╔══════════════════════════════════════════════════════════╗"
echo "║              Установка скилов                           ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────
# Шаг 1. Проверка ключа через Supabase REST
# ─────────────────────────────────────────
echo "▶ Проверяю ключ доступа..."

VALIDATE_RESP=$(curl -s \
  "$SUPABASE_URL/rest/v1/licenses?key=eq.$KEY&select=id,is_active,expires_at,clients(name,email)" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Accept: application/json")

LICENSE_ID=$(echo "$VALIDATE_RESP" | python3 -c "
import json, sys
from datetime import datetime, timezone
try:
    data = json.load(sys.stdin)
    if not isinstance(data, list) or len(data) == 0:
        print('INVALID')
        sys.exit(0)
    rec = data[0]
    if not rec.get('is_active', False):
        print('INACTIVE')
        sys.exit(0)
    exp = rec.get('expires_at')
    if exp:
        exp_dt = datetime.fromisoformat(exp.replace('Z', '+00:00'))
        if exp_dt < datetime.now(timezone.utc):
            print('EXPIRED')
            sys.exit(0)
    print(rec['id'])
except:
    print('ERROR')
" 2>/dev/null || echo "ERROR")

case "$LICENSE_ID" in
  INVALID)  echo "  ❌ Ключ не найден. Проверь правильность ввода."; exit 1 ;;
  INACTIVE) echo "  ❌ Лицензия деактивирована."; exit 1 ;;
  EXPIRED)  echo "  ❌ Срок действия ключа истёк."; exit 1 ;;
  ERROR)    echo "  ❌ Ошибка проверки ключа. Попробуй позже."; exit 1 ;;
esac

# Данные клиента
CLIENT_NAME=$(echo "$VALIDATE_RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['clients']['name'] if d else '')" 2>/dev/null || echo "—")
CLIENT_EMAIL=$(echo "$VALIDATE_RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['clients']['email'] if d else '')" 2>/dev/null || echo "—")
IS_ACTIVE=$(echo "$VALIDATE_RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print('активна' if d[0].get('is_active') else 'неактивна')" 2>/dev/null || echo "—")

# Последняя загрузка
LAST_DL=$(curl -s \
  "$SUPABASE_URL/rest/v1/downloads?license_id=eq.$LICENSE_ID&select=downloaded_at&order=downloaded_at.desc&limit=1" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Accept: application/json" | python3 -c "
import json, sys
from datetime import datetime, timezone
try:
    data = json.load(sys.stdin)
    if not data:
        print('нет')
        sys.exit(0)
    ts = data[0]['downloaded_at']
    dt = datetime.fromisoformat(ts.replace('Z','+00:00')).astimezone()
    print(dt.strftime('%d.%m.%Y %H:%M'))
except:
    print('нет')
" 2>/dev/null || echo "нет")

echo "  ✅ Ключ действителен"
echo ""
echo "  Клиент       : $CLIENT_NAME"
echo "  Email        : $CLIENT_EMAIL"
echo "  Лицензия     : $IS_ACTIVE"
echo "  Посл. загрузка: $LAST_DL"

echo ""

# ─────────────────────────────────────────
# Шаг 2. Загружаем manifest.json
# ─────────────────────────────────────────
echo "▶ Получаю список скилов..."

MANIFEST_URL="$SUPABASE_URL/storage/v1/object/public/$BUCKET/manifest.json?t=$(date +%s)"
MANIFEST=$(curl -fsSL "$MANIFEST_URL" 2>/dev/null) || {
  echo "  ❌ Не удалось загрузить список скилов"
  exit 1
}

SKILL_COUNT=$(echo "$MANIFEST" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
echo "  Доступно скилов: $SKILL_COUNT"
echo ""

# ─────────────────────────────────────────
# Шаг 3. Цель установки — глобально
# ─────────────────────────────────────────
TARGET_DIR="$HOME/.claude/skills/user"
mkdir -p "$TARGET_DIR"
echo "  Папка установки: $TARGET_DIR"
echo ""

# ─────────────────────────────────────────
# Шаг 4. Скачиваем и распаковываем скилы
# ─────────────────────────────────────────
echo "▶ Устанавливаю скилы..."
echo ""

INSTALLED=0
ERRORS=0
TMP_DIR=$(mktemp -d)

SKILLS=$(echo "$MANIFEST" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for name, info in data.items():
    print(f\"{name}|{info['url']}|{info['version']}\")
" 2>/dev/null || echo "")
SKILLS_LIST="$SKILLS"

if [[ -z "$SKILLS" ]]; then
  echo "  ⚠️  Список скилов пустой"
  rm -rf "$TMP_DIR"
  exit 1
fi

while IFS='|' read -r SKILL_NAME SKILL_URL SKILL_VERSION; do
  [[ -z "$SKILL_NAME" ]] && continue

  ZIP_PATH="$TMP_DIR/${SKILL_NAME}.zip"

  printf "  ⬇️  %-30s v%s ... " "$SKILL_NAME" "$SKILL_VERSION"

  if curl -fsSL "$SKILL_URL" -o "$ZIP_PATH" 2>/dev/null; then
    unzip -q -o "$ZIP_PATH" -d "$TARGET_DIR" 2>/dev/null
    printf "✅\n"
    INSTALLED=$((INSTALLED + 1))
  else
    printf "❌\n"
    ERRORS=$((ERRORS + 1))
  fi
done <<< "$SKILLS"

rm -rf "$TMP_DIR"
echo ""

# ─────────────────────────────────────────
# Шаг 5. Регистрируем скилы в ~/.claude/CLAUDE.md
# ─────────────────────────────────────────
echo "▶ Регистрирую скилы в Claude..."

CLAUDE_MD="$HOME/.claude/CLAUDE.md"
mkdir -p "$HOME/.claude"

# Собираем блок <skills>
SKILLS_XML=""
while IFS='|' read -r SKILL_NAME SKILL_URL SKILL_VERSION; do
  [[ -z "$SKILL_NAME" ]] && continue
  SKILL_FILE="$TARGET_DIR/$SKILL_NAME/SKILL.md"
  SKILL_DESC=$(grep -m1 '^description:' "$SKILL_FILE" 2>/dev/null | sed 's/^description: //' | tr -d '"' || echo "Bitrix24 skill")
  SKILLS_XML="${SKILLS_XML}
<skill>
<name>${SKILL_NAME}</name>
<description>${SKILL_DESC}</description>
<file>${SKILL_FILE}</file>
</skill>"
done <<< "$SKILLS_LIST"

NEW_BLOCK="<skills>${SKILLS_XML}
</skills>"

# Обновляем или создаём CLAUDE.md
if [[ ! -f "$CLAUDE_MD" ]]; then
  printf "%s\n" "$NEW_BLOCK" > "$CLAUDE_MD"
  echo "  ✅ Создан ~/.claude/CLAUDE.md со скилами"
elif grep -q "<skills>" "$CLAUDE_MD" 2>/dev/null; then
  # Заменяем существующий блок <skills>...</skills>
  python3 - "$CLAUDE_MD" <<PYEOF
import sys, re
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()
before = content.split('<skills>')[0].rstrip()
skills_new = open('/dev/stdin').read() if False else '''${NEW_BLOCK}'''
content_new = before + '\n\n' + skills_new + '\n' if before else skills_new + '\n'
with open(path, 'w') as f:
    f.write(content_new)
PYEOF
  echo "  ✅ Обновлён блок <skills> в ~/.claude/CLAUDE.md"
else
  printf "\n%s\n" "$NEW_BLOCK" >> "$CLAUDE_MD"
  echo "  ✅ Скилы добавлены в ~/.claude/CLAUDE.md"
fi

# ─────────────────────────────────────────
# Шаг 6. Опционально: VS Code проект
# ─────────────────────────────────────────
echo ""
printf "▶ Добавить скилы в VS Code проект? [Enter = пропустить, или укажи путь]: "
read -r VSCODE_PATH

if [[ -n "$VSCODE_PATH" ]]; then
  VSCODE_DIR="$VSCODE_PATH/.vscode"
  SETTINGS_FILE="$VSCODE_DIR/settings.json"
  INSTRUCTIONS_FILE="$VSCODE_PATH/.github/copilot-instructions.md"
  mkdir -p "$VSCODE_DIR" "$VSCODE_PATH/.github"

  if [[ ! -f "$SETTINGS_FILE" ]]; then
    cat > "$SETTINGS_FILE" <<'SETTINGS'
{
  "github.copilot.chat.codeGeneration.instructions": [
    { "file": ".github/copilot-instructions.md" }
  ]
}
SETTINGS
    echo "  ✅ Создан .vscode/settings.json"
  fi

  # copilot-instructions.md
  SKILLS_BLOCK_CP=""
  while IFS='|' read -r SKILL_NAME SKILL_URL SKILL_VERSION; do
    [[ -z "$SKILL_NAME" ]] && continue
    SKILL_FILE="$TARGET_DIR/$SKILL_NAME/SKILL.md"
    SKILL_DESC=$(grep -m1 '^description:' "$SKILL_FILE" 2>/dev/null | sed 's/^description: //' | tr -d '"' || echo "Bitrix24 skill")
    SKILLS_BLOCK_CP="${SKILLS_BLOCK_CP}
<skill>
<name>${SKILL_NAME}</name>
<description>${SKILL_DESC}</description>
<file>${SKILL_FILE}</file>
</skill>"
  done <<< "$SKILLS_LIST"

  if [[ ! -f "$INSTRUCTIONS_FILE" ]]; then
    printf '# Copilot Instructions\n\n<skills>%s\n</skills>\n' "$SKILLS_BLOCK_CP" > "$INSTRUCTIONS_FILE"
    echo "  ✅ Создан .github/copilot-instructions.md"
  else
    printf "\n<skills>%s\n</skills>\n" "$SKILLS_BLOCK_CP" >> "$INSTRUCTIONS_FILE"
    echo "  ✅ Скилы добавлены в copilot-instructions.md"
  fi
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                      ✅ ГОТОВО                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
printf "  Установлено скилов : %s\n" "$INSTALLED"
[[ "$ERRORS" -gt 0 ]] && printf "  Ошибок             : %s\n" "$ERRORS"
printf "  Папка              : %s\n" "$TARGET_DIR"
echo ""
echo "  Как использовать:"
echo "  Скилы подключены глобально — доступны в любом проекте Claude"
echo "  Перезапусти VS Code / Claude если они уже открыты"
echo ""
echo "  Для обновления запусти установку повторно с тем же ключом"
echo ""
