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
  "$SUPABASE_URL/rest/v1/licenses?key=eq.$KEY&is_active=eq.true&select=id,expires_at" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Accept: application/json")

KEY_STATUS=$(echo "$VALIDATE_RESP" | python3 -c "
import json, sys
from datetime import datetime, timezone
try:
    data = json.load(sys.stdin)
    if not isinstance(data, list) or len(data) == 0:
        print('invalid')
        sys.exit(0)
    rec = data[0]
    exp = rec.get('expires_at')
    if exp:
        exp_dt = datetime.fromisoformat(exp.replace('Z', '+00:00'))
        if exp_dt < datetime.now(timezone.utc):
            print('expired')
            sys.exit(0)
    print('valid')
except:
    print('error')
" 2>/dev/null || echo "error")

case "$KEY_STATUS" in
  valid)   echo "  ✅ Ключ действителен" ;;
  invalid) echo "  ❌ Ключ не найден. Проверь правильность ввода."; exit 1 ;;
  expired) echo "  ❌ Срок действия ключа истёк."; exit 1 ;;
  *)       echo "  ❌ Ошибка проверки ключа. Попробуй позже."; exit 1 ;;
esac

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
# Шаг 3. Определяем куда устанавливать
# ─────────────────────────────────────────
echo "▶ Выбери папку проекта VS Code для установки скилов:"
echo ""
echo "  Текущая папка: $(pwd)"
echo ""
printf "  Нажми Enter чтобы установить сюда, или введи путь: "
read -r CUSTOM_PATH

if [[ -n "$CUSTOM_PATH" ]]; then
  TARGET_BASE="$CUSTOM_PATH"
else
  TARGET_BASE="$(pwd)"
fi

TARGET_DIR="$TARGET_BASE/.claude/skills"
echo ""
echo "  Папка установки: $TARGET_DIR"
mkdir -p "$TARGET_DIR"
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
# Шаг 5. Настраиваем VS Code
# ─────────────────────────────────────────
echo "▶ Настраиваю VS Code..."

VSCODE_DIR="$TARGET_BASE/.vscode"
SETTINGS_FILE="$VSCODE_DIR/settings.json"
INSTRUCTIONS_FILE="$TARGET_BASE/.github/copilot-instructions.md"

mkdir -p "$VSCODE_DIR"
mkdir -p "$TARGET_BASE/.github"

# .vscode/settings.json — подключаем инструкции
if [[ ! -f "$SETTINGS_FILE" ]]; then
  cat > "$SETTINGS_FILE" <<'SETTINGS'
{
  "github.copilot.chat.codeGeneration.instructions": [
    { "file": ".github/copilot-instructions.md" }
  ]
}
SETTINGS
  echo "  ✅ Создан .vscode/settings.json"
else
  # Добавляем если ещё нет
  if ! grep -q "copilot-instructions.md" "$SETTINGS_FILE" 2>/dev/null; then
    echo "  ⚠️  Добавь вручную в .vscode/settings.json:"
    echo '     "github.copilot.chat.codeGeneration.instructions": [{"file": ".github/copilot-instructions.md"}]'
  else
    echo "  ✅ .vscode/settings.json уже настроен"
  fi
fi

# .github/copilot-instructions.md — регистрируем скилы
SKILLS_BLOCK=""
while IFS='|' read -r SKILL_NAME SKILL_URL SKILL_VERSION; do
  [[ -z "$SKILL_NAME" ]] && continue
  SKILL_FILE="$TARGET_DIR/$SKILL_NAME/SKILL.md"
  SKILL_DESC=$(grep -m1 '^description:' "$SKILL_FILE" 2>/dev/null | sed 's/^description: //' | tr -d '"' || echo "Bitrix24 skill")
  SKILLS_BLOCK="${SKILLS_BLOCK}
<skill>
<name>${SKILL_NAME}</name>
<description>${SKILL_DESC}</description>
<file>${SKILL_FILE}</file>
</skill>"
done <<< "$SKILLS_LIST"

if [[ ! -f "$INSTRUCTIONS_FILE" ]]; then
  cat > "$INSTRUCTIONS_FILE" <<INSTRUCTIONS
# Copilot Instructions

<skills>${SKILLS_BLOCK}
</skills>
INSTRUCTIONS
  echo "  ✅ Создан .github/copilot-instructions.md"
else
  if ! grep -q "b24-config" "$INSTRUCTIONS_FILE" 2>/dev/null; then
    # Добавляем блок скилов в конец
    printf "\n<skills>%s\n</skills>\n" "$SKILLS_BLOCK" >> "$INSTRUCTIONS_FILE"
    echo "  ✅ Скилы добавлены в существующий .github/copilot-instructions.md"
  else
    echo "  ✅ Скилы уже зарегистрированы в copilot-instructions.md"
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
echo "  Открой папку $TARGET_BASE в VS Code"
echo "  Скилы появятся автоматически в чате с Claude"
echo ""
echo "  Для обновления запусти установку повторно с тем же ключом"
echo ""
