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
# Шаг 3. Папка для загрузки
# ─────────────────────────────────────────
DOWNLOAD_TS=$(date +%Y-%m-%d_%H-%M)
TARGET_DIR="$HOME/Downloads/b24-skills_${DOWNLOAD_TS}"
mkdir -p "$TARGET_DIR"
echo "  Папка загрузки: $TARGET_DIR"
echo ""

# ─────────────────────────────────────────
# Шаг 4. Скачиваем ZIP архивы
# ─────────────────────────────────────────
echo "▶ Скачиваю скилы..."
echo ""

INSTALLED=0
ERRORS=0

SKILLS=$(echo "$MANIFEST" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for name, info in data.items():
    print(f\"{name}|{info['url']}|{info['version']}\")
" 2>/dev/null || echo "")
SKILLS_LIST="$SKILLS"

if [[ -z "$SKILLS" ]]; then
  echo "  ⚠️  Список скилов пустой"
  exit 1
fi

while IFS='|' read -r SKILL_NAME SKILL_URL SKILL_VERSION; do
  [[ -z "$SKILL_NAME" ]] && continue

  ZIP_PATH="$TARGET_DIR/${SKILL_NAME}.zip"

  printf "  ⬇️  %-30s v%s ... " "$SKILL_NAME" "$SKILL_VERSION"

  if curl -fsSL "$SKILL_URL" -o "$ZIP_PATH" 2>/dev/null; then
    printf "✅\n"
    INSTALLED=$((INSTALLED + 1))
  else
    printf "❌\n"
    ERRORS=$((ERRORS + 1))
  fi
done <<< "$SKILLS"

echo ""

# ─────────────────────────────────────────
# Шаг 5. Создаём README в папке загрузки
# ─────────────────────────────────────────
cat > "$TARGET_DIR/README.txt" <<README
b24-skills — скилы для работы с Bitrix24 в Claude
Загружено: $(date '+%d.%m.%Y %H:%M')
Клиент: ${CLIENT_NAME} (${CLIENT_EMAIL})

Как установить в Claude.ai:
1. Открой claude.ai → нажми на аватар → Settings
2. Раздел "Skills" (или "Profile")
3. Загрузи каждый .zip файл из этой папки
4. Скилы появятся в новом чате
README
echo "  ✅ README.txt создан"
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                      ✅ ГОТОВО                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
printf "  Скачано `скилов  : %s\n" "$INSTALLED"
[[ "$ERRORS" -gt 0 ]] && printf "  Ошибок             : %s\n" "$ERRORS"
printf "  Папка              : %s\n" "$TARGET_DIR"
echo ""
echo "  Дальнейшие шаги:"
echo "  1. Открой claude.ai → нажми на аватар → Settings"
echo "  2. Раздел \"Skills\" (или \"Profile\")"
echo "  3. Загрузи каждый .zip файл из папки:"
echo "     $TARGET_DIR"
echo "  4. Открой новый чат — скилы будут доступны"
echo ""
echo "  Для обновления запусти скрипт повторно с тем же ключом"
echo ""
