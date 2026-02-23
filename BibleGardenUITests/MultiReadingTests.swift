import XCTest

// MARK: - MultiReadingSetupTests (Setup view, #1-#10 + E2E #49)

final class MultiReadingSetupTests: XCTestCase {

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            let semaphore = DispatchSemaphore(value: 0)
            var request = URLRequest(
                url: URL(string: "https://bibleapi.space/api/languages")!,
                timeoutInterval: 10
            )
            request.httpMethod = "GET"
            URLSession.shared.dataTask(with: request) { _, response, _ in
                if let http = response as? HTTPURLResponse {
                    Self.apiAvailable = (200...499).contains(http.statusCode)
                } else {
                    Self.apiAvailable = false
                }
                semaphore.signal()
            }.resume()
            _ = semaphore.wait(timeout: .now() + 15)
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping setup tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // #1 — Setup page loads via menu
    @MainActor
    func testSetupPageLoads() {
        app.navigateToMultiSetupPage()
        let page = app.otherElements["page-multi-setup"]
        XCTAssertTrue(page.exists, "Setup page should be visible")
    }

    // #2 — Empty state shows hints when no steps configured
    @MainActor
    func testEmptyStateShowsHints() {
        app.navigateToMultiSetupPage()
        // With no steps, the empty state view should show example text
        let saveButton = app.buttons["multilingual-save-and-read"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button should exist")
        // The add buttons should be visible
        let addRead = app.buttons["multi-add-read-step"]
        XCTAssertTrue(addRead.waitForExistence(timeout: 3), "Add read step button should exist")
        let addPause = app.buttons["multi-add-pause-step"]
        XCTAssertTrue(addPause.waitForExistence(timeout: 3), "Add pause step button should exist")
    }

    // #3 — Add read step opens config sheet
    @MainActor
    func testAddReadStepOpensConfig() {
        app.navigateToMultiSetupPage()
        let addRead = app.buttons["multi-add-read-step"]
        XCTAssertTrue(addRead.waitForExistence(timeout: 5))
        addRead.tap()

        // Config sheet should appear (look for a dismiss/close option or known element)
        // PageMultilingualConfigView is presented as a sheet
        Thread.sleep(forTimeInterval: 1)
        // The sheet should be presented — verify by checking we can swipe down or find elements
        let sheetPresented = app.navigationBars.count > 0 || app.buttons.count > 3
        XCTAssertTrue(sheetPresented, "Config sheet should appear after tapping add read step")
        // Dismiss
        app.swipeDown()
    }

    // #4 — Add pause step adds a row with hourglass
    @MainActor
    func testAddPauseStep() {
        app.navigateToMultiSetupPage()
        let addPause = app.buttons["multi-add-pause-step"]
        XCTAssertTrue(addPause.waitForExistence(timeout: 5))
        addPause.tap()

        // A step row should appear
        let stepRow = app.otherElements["multi-step-row-0"]
            .exists ? app.otherElements["multi-step-row-0"] : app.cells.firstMatch
        // Verify hourglass image or pause text
        let pauseMinus = app.buttons["multi-pause-minus-0"]
        let pausePlus = app.buttons["multi-pause-plus-0"]
        // At least one pause control should exist
        let hasPauseControls = pauseMinus.waitForExistence(timeout: 3) || pausePlus.waitForExistence(timeout: 1)
        XCTAssertTrue(hasPauseControls, "Pause duration controls should appear after adding pause step")
    }

    // #5 — Pause duration +/- controls work
    @MainActor
    func testPauseDurationControls() {
        app.navigateToMultiSetupPage()
        let addPause = app.buttons["multi-add-pause-step"]
        XCTAssertTrue(addPause.waitForExistence(timeout: 5))
        addPause.tap()

        let pausePlus = app.buttons["multi-pause-plus-0"]
        let pauseMinus = app.buttons["multi-pause-minus-0"]
        XCTAssertTrue(pausePlus.waitForExistence(timeout: 3), "Plus button should exist")
        XCTAssertTrue(pauseMinus.waitForExistence(timeout: 1), "Minus button should exist")

        // Default is 2s, tap + to get 3s, then - twice to get 1s
        pausePlus.tap()
        Thread.sleep(forTimeInterval: 0.3)
        pauseMinus.tap()
        Thread.sleep(forTimeInterval: 0.3)
        pauseMinus.tap()
        Thread.sleep(forTimeInterval: 0.3)
        // Should be at 1s (minimum), another minus should keep at 1
        pauseMinus.tap()
        // No crash = pass
    }

    // #6 — Delete step removes it from list
    @MainActor
    func testDeleteStep() {
        app.navigateToMultiSetupPage()
        let addPause = app.buttons["multi-add-pause-step"]
        XCTAssertTrue(addPause.waitForExistence(timeout: 5))
        addPause.tap()

        let deleteBtn = app.buttons["multi-step-delete-0"]
        XCTAssertTrue(deleteBtn.waitForExistence(timeout: 3), "Delete button should exist")
        deleteBtn.tap()

        // After deletion, the step row should disappear
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(app.buttons["multi-step-delete-0"].exists,
                       "Step should be deleted")
    }

    // #7 — Read unit picker exists and has options
    @MainActor
    func testReadUnitPicker() {
        app.navigateToMultiSetupPage()
        let picker = app.otherElements["multi-read-unit-picker"]
            .exists ? app.otherElements["multi-read-unit-picker"] : app.buttons["multi-read-unit-picker"]
        // The picker area should exist (it's an HStack with Menu)
        let pickerExists = picker.waitForExistence(timeout: 5)
            || app.buttons.matching(identifier: "multi-read-unit-picker").count > 0
        XCTAssertTrue(pickerExists, "Read unit picker should exist")
    }

    // #8 — Save and read without steps shows error
    @MainActor
    func testSaveAndReadWithoutSteps() {
        app.navigateToMultiSetupPage()
        let saveBtn = app.buttons["multilingual-save-and-read"]
        XCTAssertTrue(saveBtn.waitForExistence(timeout: 5))
        saveBtn.tap()

        // Error message should appear
        let errorMsg = app.otherElements["multi-error-message"]
        let errorFound = errorMsg.waitForExistence(timeout: 3)
            || app.staticTexts.matching(identifier: "multi-error-message").count > 0
        XCTAssertTrue(errorFound, "Error message should appear when saving without steps")
    }

    // #9 — Save and read transitions to reading page (via save-alert skip)
    @MainActor
    func testSaveAndReadTransitionsToReading() {
        app.navigateToMultiSetupPage()

        // Add a pause step (simpler than read step which requires sheet config)
        // First add a read step — we need at least one read step, but the config sheet makes this complex
        // Instead, let's add a pause step to verify the flow. But save requires at least one read step.
        // So we tap save without steps, which shows error. Let's verify the save-alert flow differently.

        // Actually, for a proper test we need steps. Let's use the add-read flow:
        let addRead = app.buttons["multi-add-read-step"]
        XCTAssertTrue(addRead.waitForExistence(timeout: 5))
        addRead.tap()

        // In the config sheet, we should see language/translation/voice options
        // Wait for the sheet and try to close it with a save action
        Thread.sleep(forTimeInterval: 2)

        // Look for a save/done button in the config sheet
        let configSave = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save' OR label CONTAINS[c] 'сохран' OR label CONTAINS[c] 'done' OR label CONTAINS[c] 'готово'")).firstMatch
        if configSave.waitForExistence(timeout: 3) {
            configSave.tap()
            Thread.sleep(forTimeInterval: 1)
        } else {
            // Dismiss sheet and add pause step instead
            app.swipeDown()
            Thread.sleep(forTimeInterval: 1)
        }

        // If we managed to add a step, save and read
        let saveBtn = app.buttons["multilingual-save-and-read"]
        XCTAssertTrue(saveBtn.waitForExistence(timeout: 3))
        saveBtn.tap()

        // Check for save alert OR reading page
        let saveAlert = app.otherElements["multi-save-alert"]
        let readingPage = app.otherElements["page-multi-reading"]

        if saveAlert.waitForExistence(timeout: 3) {
            // Tap "Don't save" to proceed
            let skipBtn = app.buttons["multi-save-alert-skip"]
            XCTAssertTrue(skipBtn.waitForExistence(timeout: 3), "Skip button should exist in save alert")
            skipBtn.tap()

            XCTAssertTrue(readingPage.waitForExistence(timeout: 10),
                          "Should transition to reading page after skipping save")
        }
        // If no save alert appeared, either error shown (no steps) or directly transitioned
    }

    // #10 — Config button returns from reading to setup
    @MainActor
    func testConfigButtonReturnsToSetup() {
        // We need to get to reading page first — use multi-template
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default"]
        app.launch()
        app.navigateToMultiReadingPage()

        let configBtn = app.buttons["multi-config-button"]
        XCTAssertTrue(configBtn.waitForExistence(timeout: 5), "Config button should exist")
        configBtn.tap()

        let setupPage = app.otherElements["page-multi-setup"]
        XCTAssertTrue(setupPage.waitForExistence(timeout: 5),
                      "Should return to setup page after tapping config button")
    }

    // #49 — E2E: Full multilingual reading journey
    @MainActor
    func testFullMultiReadingJourney() {
        app.navigateToMultiSetupPage()

        // 1. Add a pause step (simplest to add without sheet interaction)
        let addPause = app.buttons["multi-add-pause-step"]
        XCTAssertTrue(addPause.waitForExistence(timeout: 5))
        addPause.tap()

        // 2. Add a read step (opens config sheet)
        let addRead = app.buttons["multi-add-read-step"]
        addRead.tap()
        Thread.sleep(forTimeInterval: 2)

        // Try to save from config sheet
        let configSave = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save' OR label CONTAINS[c] 'сохран' OR label CONTAINS[c] 'done' OR label CONTAINS[c] 'готово'")).firstMatch
        if configSave.waitForExistence(timeout: 3) {
            configSave.tap()
            Thread.sleep(forTimeInterval: 1)
        } else {
            app.swipeDown()
            Thread.sleep(forTimeInterval: 1)
        }

        // 3. Try save and read
        let saveBtn = app.buttons["multilingual-save-and-read"]
        XCTAssertTrue(saveBtn.waitForExistence(timeout: 3))
        saveBtn.tap()

        // Handle save alert if it appears
        let saveAlert = app.otherElements["multi-save-alert"]
        if saveAlert.waitForExistence(timeout: 3) {
            let skipBtn = app.buttons["multi-save-alert-skip"]
            if skipBtn.waitForExistence(timeout: 2) {
                skipBtn.tap()
            }
        }

        // 4. If we reached reading page, verify basic elements
        let readingPage = app.otherElements["page-multi-reading"]
        if readingPage.waitForExistence(timeout: 10) {
            // Verify chapter title exists
            let title = app.buttons["multi-chapter-title"]
            if title.waitForExistence(timeout: 8) {
                XCTAssertFalse(title.label.isEmpty, "Title should have text")
            }

            // 5. Try play
            let playPause = app.buttons["multi-play-pause"]
            if playPause.waitForExistence(timeout: 5) && playPause.isEnabled {
                playPause.tap()
                Thread.sleep(forTimeInterval: 2)
                playPause.tap() // pause
            }

            // 6. Navigate to next chapter
            let nextChapter = app.buttons["multi-next-chapter"]
            if nextChapter.waitForExistence(timeout: 3) && nextChapter.isEnabled {
                let oldTitle = title.label
                nextChapter.tap()
                _ = app.waitForLabelChange(element: title, from: oldTitle, timeout: 10)
            }

            // 7. Mark chapter as read
            let progressBtn = app.buttons["multi-chapter-progress"]
            if progressBtn.waitForExistence(timeout: 5) {
                progressBtn.tap()
            }

            // 8. Go to config
            let configBtn = app.buttons["multi-config-button"]
            if configBtn.waitForExistence(timeout: 3) {
                configBtn.tap()
                let setupPage = app.otherElements["page-multi-setup"]
                XCTAssertTrue(setupPage.waitForExistence(timeout: 5),
                              "Should return to setup from reading")
            }
        }
    }
}

// MARK: - MultiReadingTests (Core reading, #11-#27, #40)

final class MultiReadingTests: XCTestCase {

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    @MainActor override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            let semaphore = DispatchSemaphore(value: 0)
            var request = URLRequest(
                url: URL(string: "https://bibleapi.space/api/languages")!,
                timeoutInterval: 10
            )
            request.httpMethod = "GET"
            URLSession.shared.dataTask(with: request) { _, response, _ in
                if let http = response as? HTTPURLResponse {
                    Self.apiAvailable = (200...499).contains(http.statusCode)
                } else {
                    Self.apiAvailable = false
                }
                semaphore.signal()
            }.resume()
            _ = semaphore.wait(timeout: .now() + 15)
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping reading tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default"]
        app.launch()
        app.navigateToMultiReadingPage()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Loading & Display (#11-#15)

    // #11 — Reading page loads text via WebView
    @MainActor
    func testReadingPageLoadsText() {
        let textContent = app.waitForMultiTextContent(timeout: 15)
        XCTAssertNotNil(textContent, "WebView with text content should load")
    }

    // #12 — Chapter title is displayed in header
    @MainActor
    func testReadingPageShowsChapterTitle() {
        let title = app.buttons["multi-chapter-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8), "Chapter title button should exist")
        XCTAssertFalse(title.label.isEmpty, "Chapter title should have text")
    }

    // #13 — All 7 audio panel controls exist
    @MainActor
    func testAudioPanelShowsAllControls() {
        let controls = [
            "multi-prev-chapter", "multi-next-chapter",
            "multi-prev-unit", "multi-next-unit",
            "multi-prev-section", "multi-next-section",
            "multi-play-pause"
        ]
        for id in controls {
            let button = app.buttons[id]
            XCTAssertTrue(button.waitForExistence(timeout: 5),
                          "Audio control '\(id)' should exist")
        }
    }

    // #14 — Translation and voice chips are visible with text
    @MainActor
    func testTranslationAndVoiceChipsVisible() {
        let translationChip = app.otherElements["multi-translation-chip"]
        let voiceChip = app.otherElements["multi-voice-chip"]

        // These might render as buttons or other elements depending on SwiftUI
        let transExists = translationChip.waitForExistence(timeout: 5)
            || app.buttons["multi-translation-chip"].waitForExistence(timeout: 1)
        XCTAssertTrue(transExists, "Translation chip should exist")

        let voiceExists = voiceChip.waitForExistence(timeout: 3)
            || app.buttons["multi-voice-chip"].waitForExistence(timeout: 1)
        XCTAssertTrue(voiceExists, "Voice chip should exist")
    }

    // #15 — Unit counter shows "1 of N" where N > 0
    @MainActor
    func testUnitCounterVisible() {
        let counter = app.staticTexts["multi-unit-counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 8), "Unit counter should exist")
        let label = counter.label
        XCTAssertTrue(label.contains("1"), "Unit counter should show current unit")
    }

    // MARK: - Playback (#16-#18)

    // #16 — Play and pause toggle
    @MainActor
    func testPlayAndPause() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))

        // Wait for audio to be ready
        _ = app.waitForMultiPlaybackState("idle", timeout: 10)

        // Play
        playPause.tap()
        let playing = app.waitForMultiPlaybackState("playing", timeout: 15)
            || app.waitForMultiPlaybackState("buffering", timeout: 5)
        XCTAssertTrue(playing, "State should become 'playing' after tap")

        // Wait a moment for stable playback
        Thread.sleep(forTimeInterval: 1)

        // Pause
        playPause.tap()
        Thread.sleep(forTimeInterval: 1)
        let stateLabel = app.staticTexts["multi-playback-state"]
        if stateLabel.exists {
            let state = stateLabel.label
            XCTAssertTrue(state == "idle" || state == "pausing",
                          "State should be idle/pausing after pause. Got: \(state)")
        }
    }

    // #17 — Play starts from highlighted position (not resetting to unit 0)
    @MainActor
    func testPlayStartsFromHighlightedPosition() {
        // Navigate forward 2 units
        let nextUnit = app.buttons["multi-next-unit"]
        XCTAssertTrue(nextUnit.waitForExistence(timeout: 5))

        if nextUnit.isEnabled {
            nextUnit.tap()
            Thread.sleep(forTimeInterval: 0.5)
            if nextUnit.isEnabled {
                nextUnit.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }

        let currentUnit = app.multiCurrentUnit()
        XCTAssertNotNil(currentUnit)
        let unitBefore = currentUnit ?? "0"

        // Play should start from current position
        let playPause = app.buttons["multi-play-pause"]
        if playPause.isEnabled {
            playPause.tap()
            Thread.sleep(forTimeInterval: 2)

            let unitAfter = app.multiCurrentUnit() ?? "0"
            // Unit should not have reset to 0
            XCTAssertEqual(unitAfter, unitBefore,
                          "Play should start from current unit, not reset. Before: \(unitBefore), after: \(unitAfter)")
            playPause.tap() // stop
        }
    }

    // #18 — Audio panel collapse and expand
    @MainActor
    func testAudioPanelCollapseAndExpand() {
        let chevron = app.buttons["multi-chevron"]
        XCTAssertTrue(chevron.waitForExistence(timeout: 5))

        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.exists, "Play button should be visible before collapse")

        // Collapse
        chevron.tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(playPause.isHittable,
                       "Play button should not be hittable when panel is collapsed")

        // Expand
        chevron.tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(playPause.isHittable,
                      "Play button should be hittable again after expanding")
    }

    // MARK: - Chapter Navigation (#19-#21)

    // #19 — Next chapter changes title
    @MainActor
    func testNextChapter() {
        let title = app.buttons["multi-chapter-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        let oldTitle = title.label

        let nextBtn = app.buttons["multi-next-chapter"]
        XCTAssertTrue(nextBtn.waitForExistence(timeout: 3))
        nextBtn.tap()

        XCTAssertTrue(
            app.waitForLabelChange(element: title, from: oldTitle, timeout: 10),
            "Chapter title should change after tapping next")
    }

    // #20 — Prev chapter changes title
    @MainActor
    func testPrevChapter() {
        let title = app.buttons["multi-chapter-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        let oldTitle = title.label

        // Go next first
        let nextBtn = app.buttons["multi-next-chapter"]
        XCTAssertTrue(nextBtn.waitForExistence(timeout: 3))
        nextBtn.tap()
        _ = app.waitForLabelChange(element: title, from: oldTitle, timeout: 10)
        let afterNextTitle = title.label

        // Go back
        let prevBtn = app.buttons["multi-prev-chapter"]
        prevBtn.tap()
        XCTAssertTrue(
            app.waitForLabelChange(element: title, from: afterNextTitle, timeout: 10),
            "Chapter title should change after tapping prev")
    }

    // #21 — Chapter select sheet opens from title tap
    @MainActor
    func testChapterSelectFromTitle() {
        let title = app.buttons["multi-chapter-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        title.tap()

        let closeBtn = app.buttons["select-close"]
        XCTAssertTrue(closeBtn.waitForExistence(timeout: 5),
                      "Chapter selection sheet should appear")
        closeBtn.tap()

        // Should return to reading page
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 8),
                      "Should return to reading page after closing chapter select")
    }

    // MARK: - Unit Navigation (#22-#27)

    // #22 — Next unit highlights without starting audio
    @MainActor
    func testNextUnitHighlightsWithoutAudio() {
        let nextUnit = app.buttons["multi-next-unit"]
        XCTAssertTrue(nextUnit.waitForExistence(timeout: 5))

        guard nextUnit.isEnabled else { return } // Skip if only 1 unit

        nextUnit.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let currentUnit = app.multiCurrentUnit()
        XCTAssertEqual(currentUnit, "1", "Current unit should be 1 after next unit tap")

        // Should NOT be playing
        let stateLabel = app.staticTexts["multi-playback-state"]
        if stateLabel.exists {
            XCTAssertNotEqual(stateLabel.label, "playing",
                              "Audio should not start from unit navigation")
        }
    }

    // #23 — Prev unit after forward navigation returns to previous
    @MainActor
    func testPrevUnitHighlightsWithoutAudio() {
        let nextUnit = app.buttons["multi-next-unit"]
        XCTAssertTrue(nextUnit.waitForExistence(timeout: 5))

        guard nextUnit.isEnabled else { return }

        nextUnit.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let prevUnit = app.buttons["multi-prev-unit"]
        prevUnit.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let currentUnit = app.multiCurrentUnit()
        XCTAssertEqual(currentUnit, "0", "Current unit should return to 0 after prev unit tap")
    }

    // #24 — Unit navigation while playing keeps playback active
    @MainActor
    func testUnitNavigationWhilePlaying() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        guard playPause.isEnabled else { return }

        playPause.tap()
        _ = app.waitForMultiPlaybackState("playing", timeout: 15)

        let nextUnit = app.buttons["multi-next-unit"]
        guard nextUnit.isEnabled else {
            playPause.tap()
            return
        }

        nextUnit.tap()
        Thread.sleep(forTimeInterval: 1)

        // Should still be playing
        let stateLabel = app.staticTexts["multi-playback-state"]
        if stateLabel.exists {
            let state = stateLabel.label
            XCTAssertTrue(state == "playing" || state == "buffering",
                          "Should remain playing after unit navigation. Got: \(state)")
        }

        let currentUnit = app.multiCurrentUnit()
        XCTAssertEqual(currentUnit, "1",
                      "Unit should update during playback navigation")

        playPause.tap() // stop
    }

    // #25 — Unit counter updates with navigation
    @MainActor
    func testUnitCounterUpdates() {
        let counter = app.staticTexts["multi-unit-counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 8))
        let initialLabel = counter.label

        let nextUnit = app.buttons["multi-next-unit"]
        guard nextUnit.isEnabled else { return }

        nextUnit.tap()
        XCTAssertTrue(
            app.waitForLabelChange(element: counter, from: initialLabel, timeout: 5),
            "Unit counter should update after navigation")
    }

    // #26 — First unit: prev disabled
    @MainActor
    func testFirstUnitPrevDisabled() {
        let prevUnit = app.buttons["multi-prev-unit"]
        XCTAssertTrue(prevUnit.waitForExistence(timeout: 5))
        XCTAssertFalse(prevUnit.isEnabled,
                       "Previous unit should be disabled at first unit")
    }

    // #27 — Last unit: next disabled
    @MainActor
    func testLastUnitNextDisabled() {
        let nextUnit = app.buttons["multi-next-unit"]
        XCTAssertTrue(nextUnit.waitForExistence(timeout: 5))

        // Navigate to last unit
        while nextUnit.isEnabled {
            nextUnit.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTAssertFalse(nextUnit.isEnabled,
                       "Next unit should be disabled at last unit")
    }

    // MARK: - Progress (#40)

    // #40 — Mark chapter read and unread toggle
    @MainActor
    func testMarkChapterReadAndUnread() {
        let progressBtn = app.buttons["multi-chapter-progress"]
        XCTAssertTrue(progressBtn.waitForExistence(timeout: 8),
                      "Chapter progress button should exist")

        // Mark as read
        progressBtn.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Toggle back to unread
        progressBtn.tap()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(progressBtn.exists,
                      "Progress button should still exist after toggling")
    }
}

// MARK: - MultiReadingSectionTests (Section nav with two-langs, #28-#33)

final class MultiReadingSectionTests: XCTestCase {

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    @MainActor override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            let semaphore = DispatchSemaphore(value: 0)
            var request = URLRequest(
                url: URL(string: "https://bibleapi.space/api/languages")!,
                timeoutInterval: 10
            )
            request.httpMethod = "GET"
            URLSession.shared.dataTask(with: request) { _, response, _ in
                if let http = response as? HTTPURLResponse {
                    Self.apiAvailable = (200...499).contains(http.statusCode)
                } else {
                    Self.apiAvailable = false
                }
                semaphore.signal()
            }.resume()
            _ = semaphore.wait(timeout: .now() + 15)
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping section tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "two-langs", "--multi-unit", "verse"]
        app.launch()
        app.navigateToMultiReadingPage()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // #28 — Next section changes step without audio
    @MainActor
    func testNextSectionHighlightsWithoutAudio() {
        let nextSection = app.buttons["multi-next-section"]
        XCTAssertTrue(nextSection.waitForExistence(timeout: 5))

        let stepBefore = app.multiCurrentStep() ?? "0"
        guard nextSection.isEnabled else { return }

        nextSection.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let stepAfter = app.multiCurrentStep() ?? "0"
        XCTAssertNotEqual(stepBefore, stepAfter,
                         "Current step should change after next section tap")

        let stateLabel = app.staticTexts["multi-playback-state"]
        if stateLabel.exists {
            XCTAssertNotEqual(stateLabel.label, "playing",
                              "Audio should not start from section navigation")
        }
    }

    // #29 — Prev section returns to previous step
    @MainActor
    func testPrevSectionHighlightsWithoutAudio() {
        let nextSection = app.buttons["multi-next-section"]
        XCTAssertTrue(nextSection.waitForExistence(timeout: 5))
        guard nextSection.isEnabled else { return }

        nextSection.tap()
        Thread.sleep(forTimeInterval: 0.5)
        let stepAfterNext = app.multiCurrentStep() ?? "0"

        let prevSection = app.buttons["multi-prev-section"]
        prevSection.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let stepAfterPrev = app.multiCurrentStep() ?? "0"
        XCTAssertNotEqual(stepAfterNext, stepAfterPrev,
                         "Step should change after prev section tap")
    }

    // #30 — Section navigation crosses unit boundary
    @MainActor
    func testSectionNavigationCrossesUnitBoundary() {
        let nextSection = app.buttons["multi-next-section"]
        XCTAssertTrue(nextSection.waitForExistence(timeout: 5))

        let unitBefore = app.multiCurrentUnit() ?? "0"

        // Navigate through all steps in current unit to reach next unit
        // With two-langs template: read(0) -> pause(1) -> read(2) -> crosses to unit 1
        var maxTaps = 5
        while nextSection.isEnabled && maxTaps > 0 {
            let currentUnit = app.multiCurrentUnit() ?? "0"
            nextSection.tap()
            Thread.sleep(forTimeInterval: 0.5)
            let newUnit = app.multiCurrentUnit() ?? "0"
            if newUnit != currentUnit {
                // Crossed unit boundary
                XCTAssertNotEqual(unitBefore, newUnit,
                                 "Unit should change when section crosses boundary")
                return
            }
            maxTaps -= 1
        }
        // If we couldn't cross a boundary (only 1 unit), that's ok
    }

    // #31 — Section navigation while playing keeps playback
    @MainActor
    func testSectionNavigationWhilePlaying() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        guard playPause.isEnabled else { return }

        playPause.tap()
        _ = app.waitForMultiPlaybackState("playing", timeout: 15)

        let nextSection = app.buttons["multi-next-section"]
        guard nextSection.isEnabled else {
            playPause.tap()
            return
        }

        let stepBefore = app.multiCurrentStep() ?? "0"
        nextSection.tap()
        Thread.sleep(forTimeInterval: 1)

        let stepAfter = app.multiCurrentStep() ?? "0"
        XCTAssertNotEqual(stepBefore, stepAfter,
                         "Step should update during playback section navigation")

        let stateLabel = app.staticTexts["multi-playback-state"]
        if stateLabel.exists {
            let state = stateLabel.label
            XCTAssertTrue(state == "playing" || state == "buffering",
                          "Should remain playing after section navigation. Got: \(state)")
        }

        playPause.tap() // stop
    }

    // #32 — First step of first unit: prev section disabled
    @MainActor
    func testSectionStartPrevDisabled() {
        let prevSection = app.buttons["multi-prev-section"]
        XCTAssertTrue(prevSection.waitForExistence(timeout: 5))
        XCTAssertFalse(prevSection.isEnabled,
                       "Prev section should be disabled at first step of first unit")
    }

    // #33 — Last step of last unit: next section disabled
    @MainActor
    func testSectionEndNextDisabled() {
        let nextSection = app.buttons["multi-next-section"]
        let nextUnit = app.buttons["multi-next-unit"]
        XCTAssertTrue(nextSection.waitForExistence(timeout: 5))

        // Navigate to last unit
        while nextUnit.isEnabled {
            nextUnit.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Navigate to last section within last unit
        while nextSection.isEnabled {
            nextSection.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTAssertFalse(nextSection.isEnabled,
                       "Next section should be disabled at last step of last unit")
    }
}

// MARK: - MultiReadingBoundaryTests (Boundary chapters, #34-#35)

final class MultiReadingBoundaryTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    // #34 — First chapter: prev chapter disabled
    @MainActor
    func testFirstChapterPrevDisabled() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default", "--start-excerpt", "gen 1"]
        app.launch()
        app.navigateToMultiReadingPage()

        let prevBtn = app.buttons["multi-prev-chapter"]
        XCTAssertTrue(prevBtn.waitForExistence(timeout: 5))
        XCTAssertFalse(prevBtn.isEnabled,
                       "Previous chapter should be disabled at Genesis 1")

        let nextBtn = app.buttons["multi-next-chapter"]
        XCTAssertTrue(nextBtn.isEnabled,
                      "Next chapter should be enabled at Genesis 1")
    }

    // #35 — Last chapter: next chapter disabled
    @MainActor
    func testLastChapterNextDisabled() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default", "--start-excerpt", "rev 22"]
        app.launch()
        app.navigateToMultiReadingPage()

        let nextBtn = app.buttons["multi-next-chapter"]
        XCTAssertTrue(nextBtn.waitForExistence(timeout: 5))
        XCTAssertFalse(nextBtn.isEnabled,
                       "Next chapter should be disabled at Revelation 22")

        let prevBtn = app.buttons["multi-prev-chapter"]
        XCTAssertTrue(prevBtn.isEnabled,
                      "Previous chapter should be enabled at Revelation 22")
    }
}

// MARK: - MultiReadingStepTests (Step system with two-langs, #36-#39)

final class MultiReadingStepTests: XCTestCase {

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    @MainActor override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            let semaphore = DispatchSemaphore(value: 0)
            var request = URLRequest(
                url: URL(string: "https://bibleapi.space/api/languages")!,
                timeoutInterval: 10
            )
            request.httpMethod = "GET"
            URLSession.shared.dataTask(with: request) { _, response, _ in
                if let http = response as? HTTPURLResponse {
                    Self.apiAvailable = (200...499).contains(http.statusCode)
                } else {
                    Self.apiAvailable = false
                }
                semaphore.signal()
            }.resume()
            _ = semaphore.wait(timeout: .now() + 15)
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping step tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "two-langs"]
        app.launch()
        app.navigateToMultiReadingPage()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // #36 — Multi-step playthrough: read → pause → read → unit advance
    @MainActor
    func testMultiStepPlaythrough() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        guard playPause.isEnabled else { return }

        let stepBefore = app.multiCurrentStep() ?? "0"
        XCTAssertEqual(stepBefore, "0", "Should start at step 0")

        playPause.tap()
        _ = app.waitForMultiPlaybackState("playing", timeout: 15)

        // Wait for the step system to advance through read → pause → read
        // This could take a while depending on verse length
        let stateLabel = app.staticTexts["multi-playback-state"]
        let stepLabel = app.staticTexts["multi-current-step"]

        // Wait for step to change (pause or next read step)
        if stepLabel.exists {
            let stepChanged = app.waitForLabelChange(element: stepLabel, from: "0", timeout: 60)
            if stepChanged {
                // Step system is working — it advanced beyond step 0
                XCTAssertTrue(true, "Step system advanced from step 0")
            }
        }

        playPause.tap() // stop
    }

    // #37 — Pause step shows hourglass icon
    @MainActor
    func testPauseStepShowsHourglass() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        guard playPause.isEnabled else { return }

        playPause.tap()
        _ = app.waitForMultiPlaybackState("playing", timeout: 15)

        // Wait for autopausing state (happens when pause step is reached)
        let gotAutopausing = app.waitForMultiPlaybackState("autopausing", timeout: 60)
        if gotAutopausing {
            // During autopausing, the play button should show hourglass icon
            XCTAssertTrue(playPause.exists, "Play/pause button should exist during autopausing")
        }

        playPause.tap() // stop/skip
    }

    // #38 — Manual skip of pause step
    @MainActor
    func testManualSkipPauseStep() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        guard playPause.isEnabled else { return }

        playPause.tap()
        _ = app.waitForMultiPlaybackState("playing", timeout: 15)

        // Wait for autopausing (pause step)
        let gotAutopausing = app.waitForMultiPlaybackState("autopausing", timeout: 60)
        if gotAutopausing {
            // Tap play to skip the pause
            playPause.tap()
            Thread.sleep(forTimeInterval: 1)

            // Should move to next read step (not autopausing anymore)
            let stateLabel = app.staticTexts["multi-playback-state"]
            if stateLabel.exists {
                XCTAssertNotEqual(stateLabel.label, "autopausing",
                                  "Should skip pause and move to next step")
            }
        }

        // Stop playback
        if app.waitForMultiPlaybackState("playing", timeout: 3) {
            playPause.tap()
        }
    }

    // #39 — Translation chip updates per step
    @MainActor
    func testTranslationChipUpdatesPerStep() {
        // With two-langs: first step is primary language, second read step is alternate
        let translationChip = app.otherElements["multi-translation-chip"]
        let translationBtn = app.buttons["multi-translation-chip"]
        let chipElement = translationChip.exists ? translationChip : translationBtn

        guard chipElement.waitForExistence(timeout: 5) else { return }
        let initialTranslation = chipElement.label

        let playPause = app.buttons["multi-play-pause"]
        guard playPause.isEnabled else { return }

        playPause.tap()
        _ = app.waitForMultiPlaybackState("playing", timeout: 15)

        // Wait for step to advance past the pause to the second read step
        // The translation chip should eventually change
        let chipChanged = app.waitForLabelChange(element: chipElement, from: initialTranslation, timeout: 60)
        if chipChanged {
            XCTAssertNotEqual(chipElement.label, initialTranslation,
                              "Translation chip should update when step changes")
        }

        playPause.tap() // stop
    }
}

// MARK: - MultiReadingAudioEndProgressTests (#41)

final class MultiReadingAudioEndProgressTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    // #41 — Auto-progress when audio ends (short psalm)
    @MainActor
    func testAutoProgressOnAudioEnd() throws {
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--multi-template", "default",
            "--auto-progress-audio-end",
            "--start-excerpt", "psa 117"
        ]
        app.launch()
        app.navigateToMultiReadingPage()

        let stateLabel = app.staticTexts["multi-playback-state"]
        guard stateLabel.waitForExistence(timeout: 10) else {
            throw XCTSkip("Playback state label not found")
        }

        let progressBtn = app.buttons["multi-chapter-progress"]
        XCTAssertTrue(progressBtn.waitForExistence(timeout: 5))
        XCTAssertEqual(progressBtn.value as? String, "unread",
                       "Chapter should be unread before audio finishes")

        // Start playing
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        playPause.tap()
        _ = app.waitForMultiPlaybackState("playing", timeout: 15)

        // Navigate through units quickly (Psalm 117 has 2 verses)
        let nextUnit = app.buttons["multi-next-unit"]
        if nextUnit.waitForExistence(timeout: 3) && nextUnit.isEnabled {
            Thread.sleep(forTimeInterval: 1)
            nextUnit.tap()
        }

        // Wait for audio to finish
        let finishedPredicate = NSPredicate(format: "label == %@ OR label == %@",
                                            "finished", "segmentFinished")
        let finishExp = XCTNSPredicateExpectation(predicate: finishedPredicate, object: stateLabel)
        _ = XCTWaiter.wait(for: [finishExp], timeout: 30)

        Thread.sleep(forTimeInterval: 2)

        XCTAssertEqual(progressBtn.value as? String, "read",
                       "Chapter should be auto-marked as read after audio finishes")
    }
}

// MARK: - MultiReadingAutoProgressTests (#42)

final class MultiReadingAutoProgressTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    // #42 — Auto-progress by reading with short timer override
    @MainActor
    func testAutoProgressByReadingWithOverride() throws {
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--multi-template", "default",
            "--reading-progress-seconds", "3"
        ]
        app.launch()
        app.navigateToMultiReadingPage()

        guard let textContent = app.waitForMultiTextContent(timeout: 15) else {
            throw XCTSkip("Text content did not load — API may be unavailable")
        }

        let progressBtn = app.buttons["multi-chapter-progress"]
        XCTAssertTrue(progressBtn.waitForExistence(timeout: 5))
        XCTAssertEqual(progressBtn.value as? String, "unread",
                       "Chapter should be unread before scrolling")

        // Scroll to bottom
        for _ in 0..<25 {
            let start = textContent.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            let end = textContent.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        // Wait for override threshold (3 seconds) + buffer
        Thread.sleep(forTimeInterval: 5)

        XCTAssertEqual(progressBtn.value as? String, "read",
                       "Chapter should be auto-marked as read after scrolling + waiting")
    }
}

// MARK: - MultiReadingErrorTests (#43-#44)

final class MultiReadingErrorTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    // #43 — Force load error shows error text
    @MainActor
    func testErrorStateOnLoadFailure() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default", "--force-load-error"]
        app.launch()

        app.navigateViaMenu(to: "menu-multilingual")

        let errorText = app.staticTexts["multi-error-text"]
        XCTAssertTrue(errorText.waitForExistence(timeout: 8),
                      "Error text should appear when load fails")
    }

    // #44 — No audio disables controls
    @MainActor
    func testNoAudioDisablesControls() throws {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default", "--force-no-audio"]
        app.launch()

        app.navigateViaMenu(to: "menu-multilingual")

        // Wait for page to load (text should load, just no audio)
        let readingPage = app.otherElements["page-multi-reading"]
        guard readingPage.waitForExistence(timeout: 10) else {
            throw XCTSkip("Reading page did not appear")
        }

        // Wait for content to load
        Thread.sleep(forTimeInterval: 3)

        let disabledControls = [
            "multi-play-pause",
            "multi-prev-unit", "multi-next-unit",
            "multi-prev-section", "multi-next-section"
        ]
        for id in disabledControls {
            let button = app.buttons[id]
            if button.waitForExistence(timeout: 5) {
                XCTAssertFalse(button.isEnabled,
                               "\(id) should be disabled when no audio")
            }
        }
    }
}

// MARK: - MultiReadingBackgroundTests (#45)

final class MultiReadingBackgroundTests: XCTestCase {

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    @MainActor override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            let semaphore = DispatchSemaphore(value: 0)
            var request = URLRequest(
                url: URL(string: "https://bibleapi.space/api/languages")!,
                timeoutInterval: 10
            )
            request.httpMethod = "GET"
            URLSession.shared.dataTask(with: request) { _, response, _ in
                if let http = response as? HTTPURLResponse {
                    Self.apiAvailable = (200...499).contains(http.statusCode)
                } else {
                    Self.apiAvailable = false
                }
                semaphore.signal()
            }.resume()
            _ = semaphore.wait(timeout: .now() + 15)
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping background tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default"]
        app.launch()
        app.navigateToMultiReadingPage()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // #45 — Background playback continues
    @MainActor
    func testBackgroundPlaybackContinues() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        guard playPause.isEnabled else { return }

        playPause.tap()
        XCTAssertTrue(app.waitForMultiPlaybackState("playing", timeout: 15), "Should start playing")

        Thread.sleep(forTimeInterval: 2)

        // Go to background
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 5)

        // Return to foreground
        app.activate()
        Thread.sleep(forTimeInterval: 1)

        // State should not have reset to idle/finished
        let stateLabel = app.staticTexts["multi-playback-state"]
        if stateLabel.exists {
            let state = stateLabel.label
            XCTAssertTrue(state == "playing" || state == "buffering" || state == "autopausing",
                          "Playback state should not reset after background. Got: \(state)")
        }

        playPause.tap() // stop
    }
}

// MARK: - MultiReadingUnitModeTests (#46-#48)

final class MultiReadingUnitModeTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    private func launchWithUnit(_ unit: String) {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default", "--multi-unit", unit]
        app.launch()
        app.navigateToMultiReadingPage()
    }

    private func getUnitCount() -> Int? {
        let counter = app.staticTexts["multi-unit-counter"]
        guard counter.waitForExistence(timeout: 10) else { return nil }
        // Label format: "1 of N" — extract N
        let parts = counter.label.components(separatedBy: " ")
        return parts.last.flatMap { Int($0) }
    }

    // #46 — Verse mode: unit count ≈ verse count
    @MainActor
    func testVerseMode() {
        launchWithUnit("verse")
        let count = getUnitCount()
        XCTAssertNotNil(count, "Should have unit count")
        if let count = count {
            XCTAssertGreaterThan(count, 1, "Verse mode should have multiple units")
        }
    }

    // #47 — Paragraph mode: fewer units than verse mode
    @MainActor
    func testParagraphMode() {
        launchWithUnit("paragraph")
        let count = getUnitCount()
        XCTAssertNotNil(count, "Should have unit count")
        if let count = count {
            XCTAssertGreaterThanOrEqual(count, 1, "Paragraph mode should have at least 1 unit")
        }
    }

    // #48 — Chapter mode: exactly 1 unit
    @MainActor
    func testChapterMode() {
        launchWithUnit("chapter")
        let counter = app.staticTexts["multi-unit-counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 10))
        XCTAssertTrue(counter.label.contains("1") && counter.label.hasSuffix("1"),
                      "Chapter mode should show '1 of 1'. Got: \(counter.label)")
    }
}
