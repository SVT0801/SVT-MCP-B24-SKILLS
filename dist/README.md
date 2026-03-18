# b24-skills — публичные скилы

Папка для распространения скилов пользователям.

## Структура

```
dist/
├── install.sh          ← пользователь запускает это
└── skills/
    └── b24-config/
        └── SKILL.md    ← добавляются по мере готовности
```

## Как пользователь устанавливает

```bash
curl -fsSL https://raw.githubusercontent.com/SVT0801/b24-skills/main/dist/install.sh | bash -s -- --key=ВАШ_КЛЮЧ
```

## Как добавить новый скил в dist/

1. Подготовить SKILL.md в `.claude/skills/{name}/`
2. Скопировать в `dist/skills/{name}/SKILL.md`
3. Добавить имя в массив `SKILLS` в `install.sh`
4. `git add . && git commit && git push`

## Статус

| Скил | Статус |
|------|--------|
| b24-config | 🚧 в разработке |
| b24-config-calls | ⏳ не готов |
| b24-config-crm-deals | ⏳ не готов |
| b24-config-tasks | ⏳ не готов |
