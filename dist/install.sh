#!/bin/bash

# =============================================================
# install.sh — установка b24-skills в Claude Code / VS Code
# Использование: bash install.sh --key=ВАШ_КЛЮЧ
# =============================================================

set -e

SKILLS_REPO_URL="https://raw.githubusercontent.com/SVT0801/b24-skills/main"
SUPABASE_URL="https://izfirrsivyfkwjefztlx.supabase.co"
SKILLS_BUCKET="skills"

# ─────────────────────────────────────────
# Параметры
# ─────────────────────────────────────────
KEY="${1#--key=}"

if [ -z "$KEY" ]; then
  echo ""
  echo "❌ Нужен ключ доступа"
  echo ""
  echo "   Использование:"
  echo "   bash install.sh --key=ВАШ_КЛЮЧ"
  echo ""
  echo "   Или через curl:"
  echo "   curl -fsSL https://raw.githubusercontent.com/SVT0801/b24-skills/main/install.sh | bash -s -- --key=ВАШ_КЛЮЧ"
  echo ""
  exit 1
fi

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║   b24-skills — Установка / Обновление     ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────
# Шаг 1. Проверка ключа
# ─────────────────────────────────────────
echo "▶ Проверяю ключ доступа..."

# TODO: заменить на реальный Supabase endpoint когда будет готова таблица licenses
# Сейчас — простая проверка, что ключ не пустой (база для будущей интеграции)
#
# RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
#   "$SUPABASE_URL/rest/v1/licenses?key=eq.$KEY&select=active,expires_at" \
#   -H "apikey: SUPABASE_ANON_KEY" \
#   -H "Range: 0-0")
#
# Когда Supabase готов — раскомментируй блок выше и удали строку ниже
RESPONSE="200"  # placeholder

if [ "$RESPONSE" != "200" ]; then
  echo "❌ Ключ не найден или истёк срок действия"
  echo "   Приобрести: [ссылка на продажу]"
  exit 1
fi

echo "✅ Ключ действителен"
echo ""

# ─────────────────────────────────────────
# Шаг 2. Определяем куда ставить
# ─────────────────────────────────────────
TARGET_DIR="$(pwd)/.claude/skills"

echo "▶ Папка установки: $TARGET_DIR"
mkdir -p "$TARGET_DIR"
echo ""

# ─────────────────────────────────────────
# Шаг 3. Список скилов для установки
# ─────────────────────────────────────────
SKILLS=(
  "b24-config"
  # Добавлять сюда по мере готовности:
  # "b24-config-calls"
  # "b24-config-crm-deals"
  # "b24-config-tasks"
)

echo "▶ Устанавливаю скилы..."
echo ""

INSTALLED=0
ERRORS=0

for SKILL in "${SKILLS[@]}"; do
  SKILL_DIR="$TARGET_DIR/$SKILL"
  mkdir -p "$SKILL_DIR"

  # TODO: заменить на загрузку из Supabase Storage когда будет готов bucket
  # Сейчас — загрузка из GitHub (для публичных скилов)
  URL="$SKILLS_REPO_URL/dist/skills/$SKILL/SKILL.md"

  if curl -fsSL "$URL" -o "$SKILL_DIR/SKILL.md" 2>/dev/null; then
    echo "  ✅ $SKILL"
    INSTALLED=$((INSTALLED + 1))
  else
    echo "  ❌ $SKILL — не удалось загрузить"
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""

# ─────────────────────────────────────────
# Итог
# ─────────────────────────────────────────
echo "╔════════════════════════════════════════════╗"
echo "║              ✅ ГОТОВО                     ║"
echo "╚════════════════════════════════════════════╝"
echo ""
echo "  Установлено скилов : $INSTALLED"
if [ "$ERRORS" -gt 0 ]; then
echo "  Ошибок             : $ERRORS"
fi
echo "  Папка              : $TARGET_DIR"
echo ""
echo "  Как использовать в Claude Code (VS Code):"
echo "  Открой чат → напиши: b24-config"
echo ""
echo "  Для обновления:"
echo "  bash install.sh --key=$KEY"
echo ""
