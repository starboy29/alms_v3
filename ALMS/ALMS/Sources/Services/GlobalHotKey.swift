import Carbon.HIToolbox

// Top-level C-compatible callback — closures that capture context can't be
// passed as C function pointers, so we route through a static property instead.
private func carbonHotKeyHandler(
    _: EventHandlerCallRef?,
    _: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    GlobalHotKey.onFire?()
    return noErr
}

final class GlobalHotKey {
    static var onFire: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    // Default: ⌃⌥Space  (keyCode 49 = kVK_Space)
    init?(keyCode: UInt32 = 49,
          modifiers: UInt32 = UInt32(controlKey) | UInt32(optionKey)) {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerErr = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyHandler,
            1, &spec, nil, &eventHandlerRef
        )
        guard handlerErr == noErr else {
            print("[GlobalHotKey] InstallEventHandler failed: \(handlerErr)")
            return nil
        }

        var hotKeyID = EventHotKeyID(signature: 0x414C_4D53, id: 1) // 'ALMS'
        let registerErr = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard registerErr == noErr else {
            print("[GlobalHotKey] RegisterEventHotKey failed: \(registerErr) — another app may own ⌃⌥Space")
            return nil
        }
    }

    deinit {
        if let ref = hotKeyRef    { UnregisterEventHotKey(ref) }
        if let ref = eventHandlerRef { RemoveEventHandler(ref) }
    }
}
