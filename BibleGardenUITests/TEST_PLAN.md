# UI Tests Structure

## File Organization

| File | Area | What's tested |
|------|------|---------------|
| `BibleGardenUITests.swift` | Base | App launches successfully |
| `MainTests.swift` | Main screen | Cards, navigation from main |
| `MenuTests.swift` | Menu | Open/close menu, navigate to all sections |
| `SimpleReadingTests.swift` | Simple reading | Read page, audio panel, chapter navigation, reading settings |
| `ChapterSelectTests.swift` | Chapter selection | OT/NT filter, book expand/collapse, chapter pick |
| `MultiReadingTests.swift` | Multilingual reading | Setup, templates, multilingual read page |
| `ProgressTests.swift` | Progress | Progress screen, stats display |
| `AboutTests.swift` | About | About page, Telegram/website links |

## Helpers

| File | Purpose |
|------|---------|
| `Helpers/XCUIApplication+Helpers.swift` | Shared navigation helpers (open menu, go to page, wait for element) |

## Conventions

- Each file = one `XCTestCase` subclass
- Tests use `.accessibilityIdentifier()` for element lookup (not localized text)
- Helper methods avoid duplication of common navigation flows

---

## MenuTests.swift ✅

Готово, 6 тестов.

| # | Тест | Что проверяет |
|---|------|---------------|
| 1 | `testMenuOpensShowsAllItemsAndCloses` | Меню открывается, все 6 пунктов на месте, меню закрывается по тапу |
| 2 | `testNavigateToMultiReadingAndBack` | Переход на мультичтение → проверка highlight → возврат на главную |
| 3 | `testNavigateToClassicReadingAndBack` | Переход на классическое чтение → highlight → возврат |
| 4 | `testNavigateToProgressAndBack` | Переход на прогресс → highlight → возврат |
| 5 | `testLanguageSheetOpensAndCloses` | Открытие/закрытие sheet выбора языка |
| 6 | `testNavigateToAboutAndBack` | Переход на «О программе» → highlight → возврат |

---

## SimpleReadingTests.swift

Тесты требуют работающий API (bibleapi.space) и сеть.

### Загрузка и отображение контента
| # | Тест | Что проверяет |
|---|------|---------------|
| 1 | `testReadPageLoadsText` | Переход через меню → WebView с текстом загрузился |
| 2 | `testReadPageShowsChapterTitle` | Заголовок (книга + глава) отображается в хедере |

### Аудио-панель и кнопки управления
| # | Тест | Что проверяет |
|---|------|---------------|
| 3 | `testAudioPanelShowsAllControls` | Панель видна, все кнопки на месте: play/pause, prev/next chapter, prev/next verse, restart, speed |
| 4 | `testPlayAndPause` | Тап play → иконка на pause → тап pause → иконка на play |
| 5 | `testSpeedButtonCycles` | Тап на скорость → label меняется (x1 → x1.2 → x1.5 → ...) |

### Навигация по главам
| # | Тест | Что проверяет |
|---|------|---------------|
| 6 | `testNextChapter` | Тап next chapter → заголовок главы меняется на следующую |
| 7 | `testPrevChapter` | Тап prev chapter → заголовок главы меняется на предыдущую |

### Выбор главы (sheet)
| # | Тест | Что проверяет |
|---|------|---------------|
| 8 | `testChapterSelectOpensAndCloses` | Тап на заголовок → sheet с testament-selector → закрытие по кнопке |
| 9 | `testChapterSelectTestamentFilter` | В sheet видны кнопки OT/NT, тап фильтрует список книг |
| 10 | `testSelectDifferentChapter` | Выбор другой главы в sheet → sheet закрывается → заголовок обновился → текст загрузился |

### Настройки чтения (sheet)
| # | Тест | Что проверяет |
|---|------|---------------|
| 11 | `testSettingsOpensAndShowsSections` | Тап на шестерёнку → sheet с секциями language, translation, voice → закрытие |
| 12 | `testSettingsChangeTranslation` | Открыть настройки → развернуть секцию перевода → выбрать другой → закрыть → текст обновился |
| 13 | `testSettingsFontSize` | Открыть настройки → увеличить/уменьшить шрифт → превью обновляется |
| 14 | `testSettingsPauseType` | Открыть настройки → выбрать тип паузы (none/time/full) → контролы длительности появляются/скрываются |

### Аудио + стихи
| # | Тест | Что проверяет |
|---|------|---------------|
| 15 | `testPlayAdvancesVerseCounter` | Запустить play → подождать → номер стиха в таймлайне увеличивается (аудио реально играет) |
| 16 | `testNextVerseButton` | Во время воспроизведения тап next verse → перескакивает на следующий стих |
| 17 | `testRestartButton` | Во время воспроизведения тап restart → возвращается к началу главы |

### Аудио-информация
| # | Тест | Что проверяет |
|---|------|---------------|
| 18 | `testAudioInfoShowsTranslation` | На панели виден текущий перевод (например "SYNO") |
| 19 | `testAudioInfoShowsVoice` | На панели видно имя диктора |

### Отметка прочитанного
| # | Тест | Что проверяет |
|---|------|---------------|
| 20 | `testMarkChapterAsRead` | Тап на кружок прогресса → глава отмечается прочитанной (checkmark появляется) |

### Новые accessibility identifiers (нужно добавить)

**PageReadView.swift:**
- Фон страницы → `page-reading`
- Кнопка restart → `read-restart`
- Кнопка prev verse → `read-prev-verse`
- Кнопка next verse → `read-next-verse`
- Кнопка speed → `read-speed`
- Чип перевода → `read-translation-chip`
- Чип диктора → `read-voice-chip`
- Кружок прогресса главы → `read-chapter-progress`
- Текст стиха (счётчик) → `read-verse-counter`

**PageReadSettingsView.swift:**
- Close button → `settings-close`
- Кнопка уменьшить шрифт → `settings-font-decrease`
- Кнопка увеличить шрифт → `settings-font-increase`
- Текст размера шрифта → `settings-font-size`
- Кнопка сбросить шрифт → `settings-font-reset`
