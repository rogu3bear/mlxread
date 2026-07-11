import AppKit
import CoreGraphics

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
final class GlobalHotkeyService: @unchecked Sendable {
    private let configuration: HotkeyConfiguration
    /// Invoked on the main queue when the shortcut fires.
    private let handler: @MainActor @Sendable () -> Void

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var thread: Thread?
    private var threadRunLoop: CFRunLoop?
    private let stateLock = NSLock()

    private(set) var isRunning = false

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
        guard !isRunning else { return }

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
            AppLogger.hotkey.error("CGEvent.tapCreate failed (missing Accessibility trust?)")
            throw UserFacingSpeechError.hotkeyInstallFailed
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source

        let thread = Thread { [weak self] in
            guard let self, let source = self.runLoopSource else { return }
            self.threadRunLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "me.jkca.mlxread.eventtap"
        thread.qualityOfService = .userInteractive
        thread.start()
        self.thread = thread
        isRunning = true
        AppLogger.hotkey.info("Event tap installed")
    }

    func stop() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard isRunning else { return }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource, let runLoop = threadRunLoop {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFRunLoopStop(runLoop)
        }
        tap = nil
        runLoopSource = nil
        threadRunLoop = nil
        thread = nil
        isRunning = false
        AppLogger.hotkey.info("Event tap removed")
    }

    // MARK: - Tap callback plumbing (called on the tap thread)

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
                AppLogger.hotkey.notice("Event tap re-enabled after \(type == .tapDisabledByTimeout ? "timeout" : "user input disable")")
            }
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
