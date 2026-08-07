import AppKit.NSRunningApplication
import Defaults
import KeyboardShortcuts
import Observation

enum PopupState {
  // Default; shortcut will toggle the popup
  case toggle
  // In this mode, every additional press of the main key
  // will cycle to the next item in the paste history list.
  // Releasing the modifier keys will accept selection and close the popup
  case cycle
}

@Observable
class Popup {
  static let verticalSeparatorPadding = 6.0
  static let horizontalSeparatorPadding = 6.0
  static let verticalPadding: CGFloat = 5
  static let horizontalPadding: CGFloat = 5
  static let minimumPreviewHeight: CGFloat = 150

  // Radius used for items inset by the padding. Ensures they visually have the same curvature
  // as the menu.
  static let cornerRadius: CGFloat = if #available(macOS 26.0, *) {
    7
  } else {
    4
  }

  static let itemHeight: CGFloat = if #available(macOS 26.0, *) {
    24
  } else {
    22
  }

  // Timeout in seconds for auto-selecting when in cycle mode without new key presses
  private static let cycleAutoSelectTimeout: TimeInterval = 0.5

  var needsResize = false
  var height: CGFloat = 0
  var headerHeight: CGFloat = 0
  var extraTopHeight: CGFloat = 0
  var extraBottomHeight: CGFloat = 0
  var footerHeight: CGFloat = 0

  var minimumHeight: CGFloat {
    // Reserve space for 3 items
    return suitableHeight(for: 3 * Popup.itemHeight)
  }

  private var eventsMonitor: Any?

  private var state: PopupState = .toggle
  private var keyDownCount = 0
  private var modifiersHeld = false
  private var cycleAutoSelectWorkItem: DispatchWorkItem?
  private var justOpened = false

  private var isRunningTests: Bool {
    CommandLine.arguments.contains("enable-testing")
  }

  init() {
    KeyboardShortcuts.onKeyDown(for: .popup, action: handleFirstKeyDown)
    if !isRunningTests {
      KeyboardShortcuts.enable(.popup)
    }
    initEventsMonitor()
  }

  deinit {
    deinitEventsMonitor()
  }

  func initEventsMonitor() {
    guard eventsMonitor == nil else { return }

    self.eventsMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.flagsChanged, .keyDown],
      handler: handleEvent
    )
  }

  func deinitEventsMonitor() {
    if let eventsMonitor {
      NSEvent.removeMonitor(eventsMonitor)
    }
  }

  func open(height: CGFloat, at popupPosition: PopupPosition = Defaults[.popupPosition]) {
    AppState.shared.appDelegate?.panel.open(height: height, at: popupPosition)
  }

  func reset() {
    state = .toggle
    keyDownCount = 0
    modifiersHeld = false
    justOpened = false
    cycleAutoSelectWorkItem?.cancel()
    cycleAutoSelectWorkItem = nil
    if !isRunningTests {
      KeyboardShortcuts.enable(.popup)
    }
  }

  func close() {
    AppState.shared.appDelegate?.panel.close()  // close() calls reset
  }

  func isClosed() -> Bool {
    AppState.shared.appDelegate?.panel.isPresented != true
  }

  func preferredHeight(for newHeight: CGFloat) -> CGFloat {
    var height = newHeight

    var minHeight = self.minimumHeight
    // If the preview is non-empty make sure the window accomodates for it to be visible.
    if AppState.shared.preview.state.isOpen && AppState.shared.navigator.leadSelection != nil {
      minHeight += Self.minimumPreviewHeight
    }
    minHeight = max(headerHeight + Self.verticalPadding, minHeight)

    height = max(height, minHeight)
    height = min(height, Defaults[.windowSize].height)
    return height
  }

  private func suitableHeight(for historyListHeight: CGFloat) -> CGFloat {
    return historyListHeight + headerHeight + extraTopHeight + extraBottomHeight + footerHeight
  }

  func resize(height: CGFloat) {
    self.height = suitableHeight(for: height)
    AppState.shared.appDelegate?.panel.verticallyResize(to: preferredHeight(for: self.height))
    needsResize = false
  }

  private func handleFirstKeyDown() {
    if isClosed() {
      open(height: height)
      state = .cycle
      keyDownCount = 0
      justOpened = true
      // Select the first item so that cycling can work immediately
      AppState.shared.navigator.highlightFirst()
      // Start the auto-select timer when entering cycle mode
      scheduleCycleAutoSelect()
      if !isRunningTests {
        KeyboardShortcuts.disable(.popup)
      }
      return
    }

    close()
  }

  private func handleEvent(_ event: NSEvent) -> NSEvent? {
    switch event.type {
    case .keyDown:
      return handleKeyDown(event)
    case .flagsChanged:
      return handleFlagsChanged(event)
    default:
      break
    }

    return event
  }

  private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
    if isHotKeyCode(Int(event.keyCode)) {
      if let item = History.shared.pressedShortcutItem {
        cancelCycleAutoSelect()
        AppState.shared.navigator.select(item: item)
        let modifierFlags = NSEvent.ModifierFlags.currentModifierFlags
        Task { @MainActor in
          AppState.shared.history.select(item, flags: modifierFlags)
        }
        return nil
      }

      if state == .cycle {
        if justOpened {
          // First key press just opened the popup, don't cycle yet
          justOpened = false
          return nil
        }
        keyDownCount += 1
        if AppState.shared.navigator.leadSelection == nil {
          AppState.shared.navigator.highlightFirst()
        } else {
          AppState.shared.navigator.highlightNext(allowCycle: true)
        }
        // Reset the auto-select timer on each new key press
        scheduleCycleAutoSelect()
        return nil
      }

      if state == .toggle && isHotKeyModifiers(event.modifierFlags) {
        keyDownCount += 1

        if !isClosed() && keyDownCount > 1 {
          // Popup is open and this is a repeat keyDown while modifiers held → cycle
          state = .cycle
          if AppState.shared.navigator.leadSelection == nil {
            AppState.shared.navigator.highlightFirst()
          } else {
            AppState.shared.navigator.highlightNext(allowCycle: true)
          }
          // Start the auto-select timer when entering cycle mode
          scheduleCycleAutoSelect()
          return nil
        }
        // Popup is closed or this is the first keyDown → toggle popup
        handleFirstKeyDown()
        return nil
      }
    }

    return event
  }

  private func handleFlagsChanged(_ event: NSEvent) -> NSEvent? {
    // Track modifier state: XCUIElement.perform may hold modifiers logically
    // but not reflect them in synthesized keyDown events' modifierFlags.
    modifiersHeld = !event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty

    // Reset the keyDown count when modifiers are released
    if allModifiersReleased(event) {
        keyDownCount = 0
    }

    // If we are in cycle mode, releasing modifiers triggers a selection
    if state == .cycle && allModifiersReleased(event) {
      cancelCycleAutoSelect()
      state = .toggle
      let modifierFlags = NSEvent.ModifierFlags.currentModifierFlags
      DispatchQueue.main.async {
        AppState.shared.select(flags: modifierFlags)
      }
      return nil
    }

    return event
  }

  private func scheduleCycleAutoSelect() {
    cancelCycleAutoSelect()

    let workItem = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      // If we're still in cycle mode after timeout, auto-select the current item
      if self.state == .cycle {
        self.state = .toggle
        let modifierFlags = NSEvent.ModifierFlags.currentModifierFlags
        AppState.shared.select(flags: modifierFlags)
      }
    }

    cycleAutoSelectWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.cycleAutoSelectTimeout, execute: workItem)
  }

  private func cancelCycleAutoSelect() {
    cycleAutoSelectWorkItem?.cancel()
    cycleAutoSelectWorkItem = nil
  }

  private func isHotKeyCode(_ keyCode: Int) -> Bool {
    if isRunningTests {
      return keyCode == 8  // kVK_ANSI_C
    }

    guard let shortcut = KeyboardShortcuts.Name.popup.shortcut else {
      return false
    }

    return shortcut.key?.rawValue == keyCode
  }

  private func isHotKeyModifiers(_ modifiers: NSEvent.ModifierFlags) -> Bool {
    if isRunningTests {
      // In test mode, XCUIElement.perform(withKeyModifiers:) may hold modifiers
      // logically but not reflect them in synthesized keyDown events' modifierFlags.
      // Use the tracked modifier state from flagsChanged events instead.
      return modifiersHeld
    }

    guard let shortcut = KeyboardShortcuts.Name.popup.shortcut else {
      return false
    }

    return modifiers.intersection(.deviceIndependentFlagsMask) ==
      shortcut.modifiers.intersection(.deviceIndependentFlagsMask)
  }

  private func allModifiersReleased(_ event: NSEvent) -> Bool {
    return event.modifierFlags.isDisjoint(with: .deviceIndependentFlagsMask)
  }
}
