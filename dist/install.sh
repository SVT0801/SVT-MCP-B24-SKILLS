#!/usr/bin/env bash
# =============================================================
# install.sh — установка b24-skills в Claude Code / VS Code
# Использование: bash install.sh --key=ВАШ_КЛЮЧ
# =============================================================

set -euo pipefail

SUPABASE_URL="https://izfirrsivyfkwjefztlx.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml6ZmlycnNpdnlma3dqZWZ6dGx4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4MDQ2NzUsImV4cCI6MjA4OTM4MDY3NX0.uDGUlWsecO9pyFytT57ydSRWcslhFONCllZsfoLSq1E"
BUCKET="skills"

# ─────────────────────────────────────────
# Параметры
# ─────────────────────────────────────────
KEY=""
for ARG in "$@"; do
  case "$ARG" in
    --key=*) KEY="${ARG#--key=}" ;;
  esac
done

if [[ -z "$KEY" ]]; then
  echo ""
  echo "❌ Нужен ключ доступа"
  echo ""
  echo "   Использование:"
  echo "   bash install.sh --key=ВАШ_КЛЮЧ"
  echo ""
  echo "   Или через curl:"
  echo "   curl -fsSL https://raw.githubusercontent.com/SVT0801/SVT-MCP-B24-SKILLS/main/dist/install.sh | bash -s -- --key=ВАШ_КЛЮЧ"
  echo ""
  exit 1
fi

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║   b24-skills — Установка / Обновление     ║"
echo "╚════════════════════════════════════════════╝"
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
  valid)   echo "✅ Ключ действителен" ;;
  invalid) echo "❌ Ключ не найден. Проверь правильность ввода."; exit 1 ;;
  expired) echo "❌ Срок действия ключа истёк."; exit 1 ;;
  *)       echo "❌ Ошибка проверки ключа. Попробуй позже."; exit 1 ;;
esac

echo ""

# ─────────────────────────────────────────
# Шаг 2. Загружаем manifest.json
# ─────────────────────────────────────────
echo "▶ Получаю список скилов..."

MANIFEST_URL="$SUPABASE_URL/storage/v1/object/public/$BUCKET/manifest.json?t=$(date +%s)"
MANIFEST=$(curl -fsSL "$MANIFEST_URL" 2>/dev/null) || {
  echo "❌ Не удалось загрузить manifest.json"
  echo "   URL: $MANIFEST_URL"
  exit 1
}

SKILL_COUNT=$(echo "$MANIFEST" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
echo "   Доступно скилов: $SKILL_COUNT"
echo ""

# ─────────────────────────────────────────
# Шаг 3. Определяем куда устанавливать
# ─────────────────────────────────────────
TARGET_DIR="$(pwd)/.claude/skills"
echo "▶ Папка установки: $TARGET_DIR"
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

# Получаем список скилов из манифеста
SKILLS=$(echo "$MANIFEST" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for name, info in data.items():
    print(f\"{name}|{info['url']}|{info['version']}\")
" 2>/dev/null || echo "")

if [[ -z "$SKILLS" ]]; then
  echo "⚠️  Manifest пустой или не содержит скилов"
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
# Итог
# ─────────────────────────────────────────
echo "╔════════════════════════════════════════════╗"
echo "║              ✅ ГОТОВО                     ║"
echo "╚════════════════════════════════════════════╝"
echo ""
printf "  Установлено скилов : %s\n" "$INSTALLED"
[[ "$ERRORS" -gt 0 ]] && printf "  Ошибок             : %s\n" "$ERRORS"
printf "  Папка              : %s\n" "$TARGET_DIR"
echo ""
echo "  Как использовать в Claude Code (VS Code):"
echo "  Открой чат → напиши что хочешь настроить в Bitrix24"
echo ""
echo "  Для обновления:"
echo "  bash install.sh --key=$KEY"
echo ""
