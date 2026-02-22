import AVFoundation
import Combine
import MediaPlayer

// MARK: PlayerTimeObserver

class PlayerTimeObserver {
    let publisher = PassthroughSubject<TimeInterval, Never>()
    private weak var player: AVPlayer?
    private var timeObservation: Any?
    private var paused = false
    
    init(player: AVPlayer) {
        self.player = player
        
        // Periodically observe the player's current time, whilst playing
        timeObservation = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: nil) { [weak self] time in
            guard let self = self else { return }
            // If we've not been told to pause our updates
            guard !self.paused else { return }
            // Publish the new player time
            self.publisher.send(time.seconds)
        }
    }
    
    deinit {
        if let player = player,
            let observer = timeObservation {
            player.removeTimeObserver(observer)
        }
    }
    
    func pause(_ pause: Bool) {
        paused = pause
    }
    
    
}

// MARK: PlayerDurationObserver

class PlayerDurationObserver {
   let publisher = PassthroughSubject<TimeInterval, Never>()
   private var cancellable: AnyCancellable?
   
   init(player: AVPlayer) {
       let durationKeyPath: KeyPath<AVPlayer, CMTime?> = \.currentItem?.duration
       cancellable = player.publisher(for: durationKeyPath).sink { duration in
           guard let duration = duration else { return }
           guard duration.isNumeric else { return }
           self.publisher.send(duration.seconds)
       }
   }
   
   deinit {
       cancellable?.cancel()
   }
}


// MARK: PlayerModel

class PlayerModel: ObservableObject {
    
    enum PlaybackState: Int {
        case waitingForSelection
        case waitingForPlay
        case waitingForPause
        case buffering
        case playing
        case pausing
        case autopausing
        case finished
        case segmentFinished
    }
    
    private let player: AVPlayer
    private let durationObserver: PlayerDurationObserver
    private var timeObserver: PlayerTimeObserver
    private var boundaryObserverBegin: Any?
    private var boundaryObserverEnd: Any?
    private var endPlayingObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var state = PlaybackState.waitingForSelection
    @Published var periodFrom: Double = 0
    @Published var periodTo: Double = 0
    @Published var currentDuration: TimeInterval = 0
    @Published var currentTime: TimeInterval = 0
    @Published private(set) var currentSpeed: Float = 1.0
    @Published var playbackError: Error? = nil

    private var oldState = PlaybackState.waitingForSelection
    private var audioVerses: [BibleAcousticalVerseFull] = []
    private var currentVerseIndex: Int = -1
    private var stopAtEnd = true

    var onStartVerse: ((Int) -> Void)?
    var onEndVerse: (() -> Void)?
    var smoothPauseLength = 0.3

    private var pauseTimer: Timer?
    private var itemStatusObservation: NSKeyValueObservation?
    private var bufferingWatchdog: Timer?

    private var itemTitle: String = ""
    private var itemSubtitle: String = ""
    
    // MARK: init
    init() {
        
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        
        self.player = AVPlayer()
        self.durationObserver = PlayerDurationObserver(player: self.player)
        self.timeObserver = PlayerTimeObserver(player: self.player)
        
        self.setupNowPlaying()
        self.setupRemoteTransportControls()
        
        // Observe when media duration becomes available
        durationObserver.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.currentDuration = duration
                
                if self?.state == .buffering {
                    self?.bufferingWatchdog?.invalidate()
                    self?.bufferingWatchdog = nil
                    self?.state = .waitingForPlay
                    self?.player.seek(to: CMTimeMake(value: Int64(self!.periodFrom*100), timescale: 100))
                    self?.currentTime = self?.periodFrom ?? 0
                    self?.findAndSetCurrentVerseIndex()
                }
                
                // Disable internal auto-play to avoid race conditions with View logic
                // if self?.oldState == .playing {
                //     self?.playSimple()
                // }
                
            }
            .store(in: &cancellables)
        
        // Subscribe to interruption notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
            
        // Observe position changes — only update during actual playback
        // to prevent timeline jitter during buffering (Issue 6)
        timeObserver.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                guard let self = self else { return }
                if self.player.timeControlStatus == .playing {
                    self.currentTime = time
                }
            }
            .store(in: &cancellables)
        
        // Example subscription to track completion
        endPlayingObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            // Verify this notification is for the CURRENT item
            guard let item = notification.object as? AVPlayerItem, item == self.player.currentItem else {
                 return
            }
            
            // Update state and perform cleanup when track reaches the end
            self.state = .finished
        }
    }
    
    deinit {
        // Important: remove observer to avoid leaks
        if let endPlayingObserver = endPlayingObserver {
            NotificationCenter.default.removeObserver(endPlayingObserver)
        }
        itemStatusObservation?.invalidate()
        bufferingWatchdog?.invalidate()
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            // Interruption began, pause playback
            pauseSimple()
        } else if type == .ended {
            // Interruption ended, resume playback if allowed
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    playSimple()
                }
            }
        }
    }
    
    private func setupNowPlaying() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = itemTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = itemSubtitle
        // Add extra metadata if needed
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.playSimple()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.pauseSimple()
            return .success
        }
        
        // Add other commands if needed
    }

    // MARK: Set up new track parameters
    func setItem(playerItem: AVPlayerItem, periodFrom: Double, periodTo: Double, audioVerses: [BibleAcousticalVerseFull], itemTitle: String, itemSubtitle: String) {

        self.oldState = self.state
        if self.state == .playing {
            self.pauseSimple()
        }

        self.periodFrom = periodFrom
        self.periodTo = periodTo

        self.audioVerses = audioVerses
        self.currentVerseIndex = -1
        self.stopAtEnd = true

        // Clear previous error and watchdog
        self.playbackError = nil
        self.itemStatusObservation?.invalidate()
        self.bufferingWatchdog?.invalidate()

        // Force state change to ensure observers are notified (even if already buffering)
        self.state = .waitingForSelection
        self.state = .buffering
        self.currentTime = 0
        self.currentDuration = 0

        self.deleteObservation()
        self.setObservation()

        self.itemTitle = itemTitle
        self.itemSubtitle = itemSubtitle
        self.setupNowPlaying()

        self.player.replaceCurrentItem(with: playerItem)

        // Observe item status for load failures
        self.itemStatusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if item.status == .failed {
                    self.bufferingWatchdog?.invalidate()
                    self.playbackError = item.error ?? NSError(domain: "PlayerModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown playback error"])
                    self.player.pause()
                    self.state = .waitingForSelection
                }
            }
        }

        // Watchdog: if buffering takes longer than 15s, treat as error
        self.bufferingWatchdog = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, self.state == .buffering else { return }
                self.playbackError = NSError(domain: "PlayerModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "Buffering timeout"])
                self.player.pause()
                self.state = .waitingForSelection
            }
        }
    }

    // MARK: Seek to segment (reuse current item)
    /// Switches to a different segment within the same audio item without replacing it.
    /// Used in multilingual reading when the same translation plays a different unit.
    func seekToSegment(periodFrom: Double, periodTo: Double, audioVerses: [BibleAcousticalVerseFull], itemTitle: String, itemSubtitle: String) {
        if self.state == .playing {
            self.player.pause()
        }

        self.periodFrom = periodFrom
        self.periodTo = periodTo
        self.audioVerses = audioVerses
        self.currentVerseIndex = -1
        self.stopAtEnd = true
        self.playbackError = nil

        self.deleteObservation()
        self.setObservation()

        self.itemTitle = itemTitle
        self.itemSubtitle = itemSubtitle
        self.setupNowPlaying()

        self.state = .waitingForPlay
        self.player.seek(to: CMTimeMake(value: Int64(periodFrom * 100), timescale: 100))
        self.currentTime = periodFrom
        self.findAndSetCurrentVerseIndex()
    }

    // MARK: Stop (full reset)
    /// Fully stops playback and releases resources. Used when navigating to a new chapter.
    func stop() {
        player.pause()
        deleteObservation()
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        bufferingWatchdog?.invalidate()
        bufferingWatchdog = nil
        player.replaceCurrentItem(with: nil)
        audioVerses = []
        currentVerseIndex = -1
        currentTime = 0
        currentDuration = 0
        periodFrom = 0
        periodTo = 0
        playbackError = nil
        state = .waitingForSelection
    }
    
    // Remove previous observers if needed
    private func deleteObservation() {
        if let observerBegin = boundaryObserverBegin {
            player.removeTimeObserver(observerBegin)
            self.boundaryObserverBegin = nil
        }
        if let observerEnd = boundaryObserverEnd {
            player.removeTimeObserver(observerEnd)
            self.boundaryObserverEnd = nil
        }
    }
    
    private func setObservation() {
        // Build time arrays
        var timesBegin: [NSValue] = []
        var timesEnd: [NSValue] = []
        
        for verse in audioVerses {
            let verseBeginTime = CMTime(seconds: verse.begin, preferredTimescale: 10)
            timesBegin.append(NSValue(time: verseBeginTime))
            let verseEndTime = CMTime(seconds: verse.end, preferredTimescale: 10)
            timesEnd.append(NSValue(time: verseEndTime))
        }
        
        // Observe verse start to position playback
        boundaryObserverBegin = player.addBoundaryTimeObserver(forTimes: timesBegin, queue: .main) {
            self.currentTime = CMTimeGetSeconds(self.player.currentTime())
            self.findAndSetCurrentVerseIndex()
        }
        
        // Observe verse end to trigger pauses
        boundaryObserverEnd = player.addBoundaryTimeObserver(forTimes: timesEnd, queue: .main) {
            // Stop when excerpt end is reached
            if self.stopAtEnd && self.currentVerseIndex == self.audioVerses.count - 1 {
                self.player.pause()
                self.state = .segmentFinished
            }
            // Skip end-of-verse event on last verse (prevents extra pauses and layout glitches)
            else if self.currentVerseIndex != self.audioVerses.count - 1 {
                self.onEndVerse?()
            }
        }
    }
    
    // Find verse that matches current position
    private func findAndSetCurrentVerseIndex() {
        for (index, verse) in audioVerses.enumerated() {
            // +0.1 because positioning is not exact and may trigger earlier
            if currentTime + 0.1 >= verse.begin && currentTime + 0.1 <= verse.end {
                if index != currentVerseIndex {
                }
                
                setCurrentVerseIndex(index)
                break
            }
        }
    }
    
    private func setCurrentVerseIndex(_ cur: Int) {
        if cur != self.currentVerseIndex {
            self.currentVerseIndex = cur
            self.onStartVerse?(cur)
        }
    }
    
    // MARK: Play/Pause handling
    func doPlayOrPause() {
        if self.state == .playing {
            let safeDuration = calculateSafeSmoothPauseDuration()
            pauseSmoothly(duration: safeDuration)
        }
        else if state == .buffering {
            // Do nothing while buffering
        }
        else if state == .finished {
            self.restart()
            self.playSimple()
        }
        else {
            // If playback starts after excerpt end, don't stop automatically anymore
            if self.currentTime >= self.periodTo {
                self.stopAtEnd = false
            }
            self.playSimple()
        }
    }
    
    private func playSimple() {
        self.player.play()
        self.state = .playing
    }
    
    private func pauseSimple() {
        self.player.pause()
        self.state = .pausing
    }
    
    // Calculate safe duration for smooth pause to avoid overlapping with next verse
    private func calculateSafeSmoothPauseDuration() -> TimeInterval {
        // If no smooth pause is set, return 0
        guard smoothPauseLength > 0 else { return 0 }
        
        // Find current verse and check distance to next verse
        let currentTime = CMTimeGetSeconds(player.currentTime())
        var distanceToNextVerse: Double = smoothPauseLength // default to full smooth pause length
        
        // Find current verse index based on current time
        for (index, verse) in audioVerses.enumerated() {
            if currentTime >= verse.begin && currentTime <= verse.end {
                // Check if there's a next verse
                if index + 1 < audioVerses.count {
                    let nextVerseBegin = audioVerses[index + 1].begin
                    distanceToNextVerse = nextVerseBegin - currentTime
                }
                break
            }
        }
        
        // Return the minimum of smoothPauseLength and available distance
        // Leave a small buffer (0.05 seconds) to avoid exact timing issues
        let safeDistance = max(0, distanceToNextVerse - 0.05)
        return min(smoothPauseLength, safeDistance)
    }
    
    private func pauseSmoothly(duration: TimeInterval) {
        let initialVolume = player.volume
        let steps = 10
        let interval = duration / Double(steps)
        var currentStep = 0
        
        self.state = .waitingForPause
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            if currentStep < steps {
                let newVolume = initialVolume * (1.0 - Float(currentStep) / Float(steps))
                self.player.volume = newVolume
                currentStep += 1
            } else {
                self.player.volume = initialVolume // Reset volume to original after pausing
                timer.invalidate()
                self.pauseSimple()
                let to = CMTimeGetSeconds(self.player.currentTime()) - duration
                self.player.seek(to: CMTimeMake(value: Int64(to*100), timescale: 100))
            }
        }
    }
    
    func breakForSeconds(_ seconds: Double) {
        self.player.pause()
        self.state = .autopausing
        
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            // Ensure playback wasn't fully stopped meanwhile
            if self.state == .autopausing {
                self.playSimple()
            }
        }
    }
    
    // MARK: Seeking
    func sliderEditingChanged(editingStarted: Bool) { // private
        
        if editingStarted {
            // Tell PlayerTimeObserver to stop publishing while user drags the slider
            self.timeObserver.pause(true)
        }
        else {
            // Editing finished, start the seek
            let targetTime = CMTime(seconds: currentTime, preferredTimescale: 600)
            player.seek(to: targetTime) { _ in
                self.timeObserver.pause(false)
            }
            if currentTime >= Double(periodTo == 0 ? currentDuration : periodTo) {
                stopAtEnd = false
            }
            findAndSetCurrentVerseIndex()
        }
    }
    
    func restart() {
        if state == .playing || state == .pausing || state == .finished {
            stopAtEnd = true
            setCurrentVerseIndex(-1)
            player.seek(to: CMTimeMake(value: Int64(periodFrom*100), timescale: 100))
        }
    }
    
    func previousVerse() {
        if state == .playing && currentVerseIndex > 0 {
            setCurrentVerseIndex(currentVerseIndex - 1)
            
            let begin = audioVerses[currentVerseIndex].begin
            // Pause periodic updates during the seek to avoid UI "jumping back".
            timeObserver.pause(true)
            currentTime = begin
            let targetTime = CMTime(seconds: begin, preferredTimescale: 600)
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                self?.timeObserver.pause(false)
            }
        }
    }
    
    func nextVerse() {
        if state == .playing && currentVerseIndex+1 < audioVerses.count {
            setCurrentVerseIndex(currentVerseIndex + 1)
            let begin = audioVerses[currentVerseIndex].begin
            // Step slightly back to make the transition smoother
            let minus = currentVerseIndex >= 1 ? min(abs((audioVerses[currentVerseIndex-1].end - begin) / 2), 0.1) : 0
            let target = max(0, begin - minus)
            // Pause periodic updates during the seek to avoid UI "jumping back".
            timeObserver.pause(true)
            // Keep UI in sync with the actual seek target to avoid a visible "jump back".
            currentTime = target
            let targetTime = CMTime(seconds: target, preferredTimescale: 600)
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                self?.timeObserver.pause(false)
            }
        }
    }
    
    // MARK: Playback speed
    func changeSpeed() {
        if currentSpeed >= 2 || currentSpeed < 0.6 {
            currentSpeed = 0.6
        }
        else {
            currentSpeed += 0.2
        }
        
        player.defaultRate = currentSpeed
        if state == .playing {
            player.rate = currentSpeed
        }
    }
    
    func setSpeed(speed: Float) {
        currentSpeed = speed
        player.defaultRate = speed
    }
    
    
}
