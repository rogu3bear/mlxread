import AppKit
import CoreGraphics

protocol GlobalHotkeyControlling: AnyObject {
    var isRunning: Bool { get }
    func start() throws
    func stop()
}

/// Global Option–Escape interception via CGEventTap.
///
/// - suppresses exactly the configured shortcut, passes everything else;
/// - ignores key-repeat so holding the shortcut fires once;
/// - re-enables the tap when macOS disables it (timeout / user input);
/// - runs its own thread + run loop so a busy main thread cannot stall
///   event delivery for other apps;
/// - `stop()` fully tears the tap down (also called on app termination).
///
/// Creating the tap requires Accessibility trust; `start()` throws
/// `UserFacingSpeechError.hotkeyInstallFailed` without it.
final class GlobalHotkeyService: GlobalHotkeyControlling, @unchecked Sendable {
    private let configuration: HotkeyConfiguration
    /// Invoked on the main queue when the shortcut fires.
    private let handler: @MainActor @Sendable () -> Void

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var threadRunLoop: CFRunLoop?
    private let stateLock = NSLock()

    var isRunning: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard let tap, threadRunLoop != nil else { return false }
        return CFMachPortIsValid(tap) && CGEvent.tapIsEnabled(tap: tap)
    }

    init(
        configuration: HotkeyConfiguration = .optionEscape,
        handler: @escaping @MainActor @Sendable () -> Void
    ) {
        self.configuration = configuration
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        if let tap, CFMachPortIsValid(tap) {
            // A newly created tap is still attaching to its worker's run loop.
            guard threadRunLoop != nil else { return }
            CGEvent.tapEnable(tap: tap, enable: true)
            if CGEvent.tapIsEnabled(tap: tap) { return }
        }
        stopLocked()

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyEventTapCallback,
            userInfo: selfPtr
        ) else {
            throw UserFacingSpeechError.hotkeyInstallFailed
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            throw UserFacingSpeechError.hotkeyInstallFailed
        }
        self.tap = tap
        self.runLoopSource = source

        let thread = Thread { [weak self] in
            guard let self else { return }
            let runLoop = CFRunLoopGetCurrent()
            self.stateLock.lock()
            guard self.tap === tap else {
                self.stateLock.unlock()
                return
            }
            self.threadRunLoop = runLoop
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            self.stateLock.unlock()
            CFRunLoopRun()
            self.stateLock.lock()
            if self.tap === tap { self.stopLocked() }
            self.stateLock.unlock()
        }
        thread.name = "me.jkca.mlxread.eventtap"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    func stop() {
        stateLock.lock()
        defer { stateLock.unlock() }
        stopLocked()
    }

    private func stopLocked() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)
        if let source = runLoopSource, let runLoop = threadRunLoop {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFRunLoopStop(runLoop)
        }
        self.tap = nil
        runLoopSource = nil
        threadRunLoop = nil
    }

    // MARK: - Tap callback plumbing (called on the tap thread)

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            stateLock.lock()
            if let tap, CFMachPortIsValid(tap) {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            stateLock.unlock()
            return Unmanaged.passUnretained(event)
        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if configuration.matches(keyCode: keyCode, flags: event.flags) {
                guard !isRepeat else { return nil } // swallow repeats silently
                let handler = self.handler
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { handler() }
                }
                return nil // suppress: this exact shortcut belongs to us
            }
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

/// C-convention trampoline for the event tap.
private func hotkeyEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let service = Unmanaged<GlobalHotkeyService>.fromOpaque(userInfo).takeUnretainedValue()
    return service.handle(proxy: proxy, type: type, event: event)
}
