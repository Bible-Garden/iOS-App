import XCTest

// MARK: - Demo Recording Test
// Скриптованный сценарий для записи App Store preview видео (~30 сек).
// Запуск: xcodebuild test -scheme BibleGarden -destination '...' -only-testing:BibleGardenUITests/DemoRecordingTests/testAppStoreDemo
//
// Параллельно запишите экран:
//   xcrun simctl io booted recordVideo demo.mp4

final class DemoRecordingTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo-recording"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func pause(_ seconds: TimeInterval = 0.05) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Быстрое ожидание элемента с коротким polling (не 1с как у waitForExistence)
    private func quickWait(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists { return true }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }

    /// Двойной тап: 1-й показывает индикатор (поглощается), 2-й выполняет действие.
    private func demoTap(_ element: XCUIElement, prePause: TimeInterval = 0.05, postPause: TimeInterval = 0.05) {
        pause(prePause)
        element.tap()          // preview — показывает кружок, поглощается overlay
        pause(0.1)             // зритель видит индикатор
        element.tap()          // action — проходит насквозь к кнопке
        pause(postPause)
    }

    private func waitAndTap(_ element: XCUIElement, timeout: TimeInterval = 5, postPause: TimeInterval = 0.05) {
        guard quickWait(element, timeout: timeout) else { return }
        demoTap(element, postPause: postPause)
    }

    /// Множественные тапы (для +/- кнопок) — без preview, прямые.
    private func demoTapMultiple(_ element: XCUIElement, times: Int, interval: TimeInterval = 0.05) {
        // Первый тап с preview
        element.tap()          // preview
        pause(0.1)
        element.tap()          // action
        pause(interval)
        // Остальные — без preview (быстро)
        for _ in 1..<times {
            element.tap()      // preview
            element.tap()      // action
            pause(interval)
        }
    }

    private func tapHittableText(containing keywords: [String], timeout: TimeInterval = 5, postPause: TimeInterval = 0.05) -> Bool {
        let conditions = keywords.map { "label CONTAINS[c] '\($0)'" }.joined(separator: " OR ")
        let predicate = NSPredicate(format: conditions)
        let matches = app.staticTexts.matching(predicate)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for i in 0..<matches.count {
                let element = matches.element(boundBy: i)
                if element.exists && element.isHittable {
                    element.tap()      // preview
                    pause(0.1)
                    element.tap()      // action
                    pause(postPause)
                    return true
                }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }

    // MARK: - Main Demo Scenario

    @MainActor
    func testAppStoreDemo() {

        // Сцена 1: Главная → Мультиязычное чтение
        pause(0.3)

        let multiCard = app.buttons["card-multilingual"]
        waitAndTap(multiCard)

        let setupPage = app.otherElements["page-multi-setup"]
        guard quickWait(setupPage, timeout: 8) else { return }

        // Сцена 2: Добавляем первый перевод
        let addReadBtn = app.buttons["multi-add-read-step"]
        waitAndTap(addReadBtn, postPause: 0.2)

        let configSave = app.buttons["multi-config-save"]
        waitAndTap(configSave, timeout: 8)

        // Сцена 3: Добавляем паузу
        let addPauseBtn = app.buttons["multi-add-pause-step"]
        waitAndTap(addPauseBtn)

        let pausePlus = app.buttons["multi-pause-plus-1"]
        if pausePlus.exists {
            demoTap(pausePlus)
        }

        // Сцена 4: Добавляем второй перевод
        waitAndTap(addReadBtn)

        let langSection = app.buttons["config-section-language"]
        guard quickWait(langSection, timeout: 8) else { return }

        // Язык
        demoTap(langSection)
        let foundEnglish = tapHittableText(containing: ["English"], timeout: 5)
        if !foundEnglish {
            _ = tapHittableText(containing: ["Eng"], timeout: 2)
        }

        // Перевод
        let foundTranslation = tapHittableText(
            containing: ["BSB", "KJV", "ESV", "NIV", "NASB", "NLT", "WEB", "NKJV"],
            timeout: 5
        )
        if !foundTranslation {
            let transSection = app.buttons["config-section-translation"]
            if quickWait(transSection, timeout: 2) {
                demoTap(transSection)
                _ = tapHittableText(containing: ["BSB", "KJV", "ESV", "NIV"], timeout: 3)
            }
        }

        // Голос
        let foundVoice = tapHittableText(
            containing: ["Souer", "Bob", "David", "James", "John", "Michael", "Mark"],
            timeout: 5
        )
        if !foundVoice {
            let voiceSection = app.buttons["config-section-voice"]
            if quickWait(voiceSection, timeout: 2) {
                demoTap(voiceSection)
                _ = tapHittableText(containing: ["Souer", "Bob"], timeout: 3)
            }
        }

        // Скорость 1.0x → 1.2x
        let speedPlus = app.buttons["config-speed-plus"]
        if !speedPlus.isHittable {
            app.swipeUp()
        }
        if quickWait(speedPlus, timeout: 3) {
            demoTapMultiple(speedPlus, times: 2)
        }

        // Шрифт 100% → 70%
        let fontMinus = app.buttons["config-font-minus"]
        if quickWait(fontMinus, timeout: 3) {
            demoTapMultiple(fontMinus, times: 3)
        }

        // Сохраняем второй степ
        let configSave2 = app.buttons["multi-config-save"]
        waitAndTap(configSave2, timeout: 3)

        // Показываем список степов
        pause(0.2)

        // «Сохранить и читать»
        let saveAndRead = app.buttons["multilingual-save-and-read"]
        waitAndTap(saveAndRead)

        // Save-alert — пропускаем
        let skipPredicate = NSPredicate(format: "identifier == 'multi-save-alert' AND (label CONTAINS[c] 'without' OR label CONTAINS[c] 'без' OR label CONTAINS[c] 'Не сохран')")
        let skipBtn = app.buttons.matching(skipPredicate).firstMatch
        if quickWait(skipBtn, timeout: 3) {
            demoTap(skipBtn)
        }

        // Страница чтения
        let readingPage = app.otherElements["page-multi-reading"]
        guard quickWait(readingPage, timeout: 10) else { return }

        let _ = app.waitForMultiTextContent(timeout: 10)
        pause(0.3)

        // Воспроизведение
        let playPause = app.buttons["multi-play-pause"]
        waitAndTap(playPause, postPause: 0.3)

        // Следующий стих × 2
        let nextUnit = app.buttons["multi-next-unit"]
        if quickWait(nextUnit, timeout: 3) && nextUnit.isEnabled {
            demoTap(nextUnit, postPause: 0.2)

            if nextUnit.isEnabled {
                demoTap(nextUnit, postPause: 0.2)
            }
        }

        // Финал
        pause(0.2)

        if playPause.exists && playPause.isEnabled {
            demoTap(playPause)
        }

        pause(0.1)
    }
}
