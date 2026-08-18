import Cocoa
import FlutterMacOS
import ServiceManagement

@main
class AppDelegate: FlutterAppDelegate {
  private var overlayPanel: NSPanel?
  private var statusLabel: NSTextField?
  private var waveformView: WaveformView?
  private var statusDot: NSView?
  private var dotAnimTimer: Timer?
  private var textAnimTimer: Timer?
  private var cancelButton: NSButton?
  private var escEventMonitor: Any?
  private var localEscEventMonitor: Any?
  private var controlChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    buildOverlayPanel()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(
    _ sender: NSApplication
  ) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication)
    -> Bool
  {
    return true
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication, hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      for window in sender.windows {
        window.makeKeyAndOrderFront(self)
      }
    }
    return true
  }

  // MARK: - Overlay Panel

  private func buildOverlayPanel() {
    NSLog("[ZeroType] buildOverlayPanel start")
    self.overlayPanel = OverlayPanel(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 48),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    guard let panel = self.overlayPanel else { return }
    panel.level = NSWindow.Level.statusBar
    panel.isOpaque = false
    panel.backgroundColor = NSColor.clear
    panel.hasShadow = false
    panel.ignoresMouseEvents = false
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.collectionBehavior = [NSWindow.CollectionBehavior.canJoinAllSpaces, NSWindow.CollectionBehavior.fullScreenAuxiliary]
    panel.isMovableByWindowBackground = false

    let container = NSView()
    container.wantsLayer = true
    container.layer?.backgroundColor =
      NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.96).cgColor
    container.layer?.cornerRadius = 24
    container.layer?.borderWidth = 1.0
    container.layer?.borderColor =
      NSColor(red: 1.0, green: 0.478, blue: 0.0, alpha: 0.6).cgColor
    container.translatesAutoresizingMaskIntoConstraints = false

    // Shadow layer
    container.layer?.shadowColor = NSColor(red: 1.0, green: 0.478, blue: 0.0, alpha: 0.3).cgColor
    container.layer?.shadowRadius = 16
    container.layer?.shadowOpacity = 1
    container.layer?.shadowOffset = CGSize(width: 0, height: 0)

    // Dot indicator
    let dot = NSView()
    dot.wantsLayer = true
    dot.layer?.backgroundColor =
      NSColor(red: 1.0, green: 0.478, blue: 0.0, alpha: 1.0).cgColor
    dot.layer?.cornerRadius = 5
    dot.translatesAutoresizingMaskIntoConstraints = false
    self.statusDot = dot

    // Waveform
    let waveform = WaveformView()
    waveform.translatesAutoresizingMaskIntoConstraints = false
    self.waveformView = waveform

    // Label
    let label = NSTextField(labelWithString: "錄音中")
    label.textColor = NSColor(red: 1.0, green: 0.478, blue: 0.0, alpha: 1.0)
    label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
    label.translatesAutoresizingMaskIntoConstraints = false
    self.statusLabel = label

    // Cancel (X) button
    let cancelBtn = NSButton(frame: .zero)
    if #available(macOS 11.0, *) {
      cancelBtn.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "取消")
      cancelBtn.imagePosition = .imageOnly
    } else {
      cancelBtn.title = "X"
      cancelBtn.imagePosition = .noImage
    }
    cancelBtn.bezelStyle = .inline
    cancelBtn.isBordered = false
    cancelBtn.imageScaling = .scaleProportionallyDown
    cancelBtn.contentTintColor = NSColor(red: 1.0, green: 0.478, blue: 0.0, alpha: 0.6)
    cancelBtn.target = self
    cancelBtn.action = #selector(cancelButtonTapped)
    cancelBtn.translatesAutoresizingMaskIntoConstraints = false
    self.cancelButton = cancelBtn

    container.addSubview(dot)
    container.addSubview(label)
    container.addSubview(waveform)
    container.addSubview(cancelBtn)

    let contentView = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
    contentView.wantsLayer = true
    contentView.addSubview(container)
    panel.contentView = contentView

    NSLayoutConstraint.activate([
      container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      container.topAnchor.constraint(equalTo: contentView.topAnchor),
      container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      dot.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
      dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      dot.widthAnchor.constraint(equalToConstant: 10),
      dot.heightAnchor.constraint(equalToConstant: 10),
      label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 10),
      label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      waveform.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
      waveform.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      waveform.widthAnchor.constraint(equalToConstant: 40),
      waveform.heightAnchor.constraint(equalToConstant: 22),
      cancelBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
      cancelBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      cancelBtn.widthAnchor.constraint(equalToConstant: 18),
      cancelBtn.heightAnchor.constraint(equalToConstant: 18),
    ])

    self.overlayPanel = panel
  }

  private func positionOverlay(width: CGFloat = 200) {
    guard let panel = overlayPanel else { return }
    let screen = NSScreen.main ?? NSScreen.screens.first!
    let visibleFrame = screen.visibleFrame
    let panelHeight: CGFloat = 48
    let x = visibleFrame.midX - width / 2
    let y = visibleFrame.minY + 60
    panel.setFrame(NSRect(x: x, y: y, width: width, height: panelHeight), display: true)
  }

  private func ensureOverlayExists() {
    if overlayPanel == nil {
      NSLog("[ZeroType] Building overlay panel...")
      buildOverlayPanel()
    }
  }

  private func showOverlay(status: String, message: String) {
    NSLog("[ZeroType] showOverlay called with status: \(status), message: \(message)")
    ensureOverlayExists()
    guard let panel = overlayPanel else { 
      NSLog("[ZeroType] Error: Failed to create overlayPanel")
      return 
    }
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      let width = self.updateOverlayAppearance(status: status, message: message)
      self.positionOverlay(width: width)
      
      NSLog("[ZeroType] Ordering panel front regardless...")
      panel.alphaValue = 1.0
      panel.orderFrontRegardless()
      
      self.startDotAnimation(status: status)
      self.startTextAnimation(status: status, message: message)
      self.startEscMonitor()
    }
  }

  private func hideOverlay() {
    NSLog("[ZeroType] hideOverlay called")
    DispatchQueue.main.async { [weak self] in
      self?.overlayPanel?.orderOut(nil)
      self?.stopDotAnimation()
      self?.stopTextAnimation()
      self?.stopEscMonitor()
    }
  }

  private func updateOverlayAppearance(status: String, message: String) -> CGFloat {
    statusLabel?.stringValue = message

    let (dotColor, borderColor, shadowColor): (NSColor, NSColor, NSColor) = switch status {
    case "recording":
      (
        NSColor(red: 1.0, green: 0.478, blue: 0.0, alpha: 1.0),
        NSColor(red: 1.0, green: 0.478, blue: 0.0, alpha: 0.7),
        NSColor(red: 1.0, green: 0.478, blue: 0.0, alpha: 0.4)
      )
    case "cancelling":
      (
        NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0),
        NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 0.7),
        NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 0.4)
      )
    case "saving":
      (
        NSColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0),
        NSColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 0.7),
        NSColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 0.4)
      )
    case "transcribing":
      (
        NSColor(red: 0.388, green: 0.702, blue: 1.0, alpha: 1.0),
        NSColor(red: 0.388, green: 0.702, blue: 1.0, alpha: 0.7),
        NSColor(red: 0.388, green: 0.702, blue: 1.0, alpha: 0.4)
      )
    case "done":
      (
        NSColor(red: 0.388, green: 1.0, blue: 0.561, alpha: 1.0),
        NSColor(red: 0.388, green: 1.0, blue: 0.561, alpha: 0.7),
        NSColor(red: 0.388, green: 1.0, blue: 0.561, alpha: 0.4)
      )
    default:  // error
      (
        NSColor(red: 1.0, green: 0.361, blue: 0.361, alpha: 1.0),
        NSColor(red: 1.0, green: 1.0, blue: 0.361, alpha: 0.7),
        NSColor(red: 1.0, green: 0.361, blue: 0.361, alpha: 0.4)
      )
    }

    statusDot?.layer?.backgroundColor = dotColor.cgColor
    statusLabel?.textColor = dotColor
    cancelButton?.contentTintColor = dotColor.withAlphaComponent(0.6)
    // 取消中時隱藏 X 按鈕，避免重複觸發
    cancelButton?.isHidden = (status == "cancelling")
    if let container = overlayPanel?.contentView?.subviews.first {
      container.layer?.borderColor = borderColor.cgColor
      container.layer?.shadowColor = shadowColor.cgColor
    }

    // Show waveform only when recording
    let isRecording = (status == "recording")
    waveformView?.isHidden = !isRecording

    // Calculate dynamic width
    // Layout: leading(20) + dot(10) + gap(10) + text + [gap(10)+waveform(40)]? + gap(8) + xbtn(18) + trailing(12)
    let textWidth = statusLabel?.intrinsicContentSize.width ?? 60
    var totalWidth = 20 + 10 + 10 + textWidth + 8 + 18 + 12

    if isRecording {
        totalWidth += (10 + 40) // gap + waveform width
    }

    // Account for animation dots in width to avoid jumping
    let hasTextAnim = status == "transcribing" || status == "cancelling"
    let animDotsWidth = hasTextAnim ? (statusLabel?.font?.pointSize ?? 13) * 0.8 : 0

    return max(140, totalWidth + animDotsWidth)
  }

  private func startDotAnimation(status: String) {
    stopDotAnimation()
    guard status == "recording" || status == "saving" || status == "cancelling" else { return }
    var alpha: CGFloat = 1.0
    dotAnimTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) {
      [weak self] _ in
      DispatchQueue.main.async {
        alpha = alpha > 0.3 ? 0.3 : 1.0
        self?.statusDot?.layer?.opacity = Float(alpha)
      }
    }
  }

  private func stopDotAnimation() {
    dotAnimTimer?.invalidate()
    dotAnimTimer = nil
    statusDot?.layer?.opacity = 1.0
  }

  private func startTextAnimation(status: String, message: String) {
    stopTextAnimation()
    guard status == "transcribing" || status == "cancelling" else { return }
    var dotCount = 0
    textAnimTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) {
      [weak self] _ in
      DispatchQueue.main.async {
        dotCount = (dotCount + 1) % 4
        let dots = String(repeating: ".", count: dotCount)
        // Use a non-breaking space or specific padding to keep width stable if needed
        self?.statusLabel?.stringValue = message + dots
      }
    }
  }

  private func stopTextAnimation() {
    textAnimTimer?.invalidate()
    textAnimTimer = nil
  }

  // MARK: - Cancel (X button & ESC)

  @objc private func cancelButtonTapped() {
    triggerCancel()
  }

  private func triggerCancel() {
    DispatchQueue.main.async { [weak self] in
      self?.controlChannel?.invokeMethod("cancel", arguments: nil)
    }
  }

  private func startEscMonitor() {
    guard escEventMonitor == nil else { return }
    // Global: catches ESC when another app is focused (e.g. user is in browser)
    escEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      if event.keyCode == 53 { self?.triggerCancel() }
    }
    // Local: catches ESC when ZeroType itself is the focused app
    localEscEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
      if event.keyCode == 53 { self?.triggerCancel() }
      return event
    }
  }

  private func stopEscMonitor() {
    if let monitor = escEventMonitor {
      NSEvent.removeMonitor(monitor)
      escEventMonitor = nil
    }
    if let monitor = localEscEventMonitor {
      NSEvent.removeMonitor(monitor)
      localEscEventMonitor = nil
    }
  }

  private func updateAmplitude(_ amplitude: Double) {
    DispatchQueue.main.async { [weak self] in
      self?.waveformView?.setTargetAmplitude(CGFloat(amplitude))
    }
  }

  // MARK: - Channels

  func setupChannels(messenger: FlutterBinaryMessenger) {
    setupOverlayChannel(messenger: messenger)
    setupKeyboardChannel(messenger: messenger)
    setupPermissionChannel(messenger: messenger)
    setupLaunchAtStartupChannel(messenger: messenger)
    controlChannel = FlutterMethodChannel(
      name: "com.zerotype.app/control",
      binaryMessenger: messenger
    )
  }

  private func setupOverlayChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.zerotype.app/overlay",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "show":
        let args = call.arguments as? [String: Any]
        let status = args?["status"] as? String ?? "recording"
        let message = args?["message"] as? String ?? ""
        self?.showOverlay(status: status, message: message)
        result(nil)
      case "hide":
        self?.hideOverlay()
        result(nil)
      case "updateAmplitude":
        let args = call.arguments as? [String: Any]
        let amplitude = args?["amplitude"] as? Double ?? 0.0
        self?.updateAmplitude(amplitude)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setupKeyboardChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.zerotype.app/keyboard",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard call.method == "simulatePaste" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.simulatePaste()
      result(nil)
    }
  }

  private func setupPermissionChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.zerotype.app/permission",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "checkAccessibility":
        // 兩種查詢都看：options 版有時對 adhoc debug 包會回過期的 false。
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trustedWithOptions = AXIsProcessTrustedWithOptions(options as CFDictionary)
        let trustedPlain = AXIsProcessTrusted()
        let isTrusted = trustedWithOptions || trustedPlain
        NSLog("[ZeroType] accessibility options=\(trustedWithOptions) plain=\(trustedPlain) exe=\(CommandLine.arguments.first ?? "")")
        result(isTrusted)
      case "requestAccessibility":
        // 這會跳出系統授權對話框，才能把「清單已開」綁到目前這個 debug 行程。
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        NSLog("[ZeroType] requestAccessibility trusted=\(isTrusted)")
        result(isTrusted)
      case "openAccessibilitySettings":
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        result(nil)
      case "openMicrophoneSettings":
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setupLaunchAtStartupChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "launch_at_startup", binaryMessenger: messenger)
    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "launchAtStartupIsEnabled":
        if #available(macOS 13.0, *) {
          let status = SMAppService.mainApp.status
          result(status == .enabled || status == .requiresApproval)
        } else {
          result(false)
        }
      case "launchAtStartupSetEnabled":
        guard let args = call.arguments as? [String: Any],
              let enabled = args["setEnabledValue"] as? Bool else {
          result(nil)
          return
        }
        if #available(macOS 13.0, *) {
          if enabled {
            try? SMAppService.mainApp.register()
          } else {
            try? SMAppService.mainApp.unregister()
          }
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func simulatePaste() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    NSLog("[ZeroType] simulatePaste - Accessibility trusted: \(isTrusted)")
    
    if !isTrusted {
      NSLog("[ZeroType] WARNING: Accessibility permissions not granted. A system prompt should have appeared.")
      return
    }

    guard let source = CGEventSource(stateID: .combinedSessionState) else { 
      NSLog("[ZeroType] Error: Failed to create CGEventSource")
      return 
    }
    
    let keyV: CGKeyCode = 9
    let cmdFlag = CGEventFlags.maskCommand
    
    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true) else {
      NSLog("[ZeroType] Error: Failed to create CGEventKeyDown")
      return
    }
    keyDown.flags = cmdFlag
    
    guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false) else {
      NSLog("[ZeroType] Error: Failed to create CGEventKeyUp")
      return
    }
    keyUp.flags = cmdFlag
    
    // Post to session tap which is generally more reliable for non-root apps
    keyDown.post(tap: .cgSessionEventTap)
    keyUp.post(tap: .cgSessionEventTap)
    
    NSLog("[ZeroType] simulatePaste - Events posted to session tap.")
  }
}

// MARK: - OverlayPanel subclass

class OverlayPanel: NSPanel {
  override var canBecomeKey: Bool {
    return false
  }
}

// MARK: - WaveformView

class WaveformView: NSView {
  private var currentAmplitude: CGFloat = 0.0
  private var targetAmplitude: CGFloat = 0.0
  private var animTimer: Timer?
  private var phase: Double = 0.0

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    startAnimation()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    startAnimation()
  }

  private func startAnimation() {
    animTimer?.invalidate()
    // 60 FPS animation loop
    animTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
      self?.updateFrame()
    }
  }

  private func updateFrame() {
    // Interpolation for smoothness
    let lerpFactor: CGFloat = 0.15
    let delta = (targetAmplitude - currentAmplitude) * lerpFactor
    currentAmplitude += delta
    
    if abs(targetAmplitude - currentAmplitude) < 0.001 {
        currentAmplitude = targetAmplitude
    }
    
    // Increment phase based on amplitude (higher amplitude = faster oscillation)
    // Range speed from ~3.0 to ~10.0 for natural feel
    let speed = 3.5 + Double(currentAmplitude) * 8.0
    phase += (1.0/60.0) * speed
    
    self.needsDisplay = true
  }

  func setTargetAmplitude(_ amp: CGFloat) {
    targetAmplitude = amp
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    let bars = 6
    let barWidth: CGFloat = 3
    let spacing: CGFloat = 3
    let totalWidth = CGFloat(bars) * (barWidth + spacing) - spacing
    var x = (bounds.width - totalWidth) / 2
    let color = NSColor(red: 1.0, green: 0.478, blue: 0.0, alpha: 0.85)
    color.setFill()
    
    // Use phase instead of dynamic time multiplication to avoid jitter
    for i in 0..<bars {
      let barPhase = phase + Double(i) * 0.8
      let pulse = (sin(CGFloat(barPhase)) + 1) / 2
      // Multiply amplitude effect for better visual feedback
      let barHeight = max(3, pulse * currentAmplitude * 18 + 3)
      let y = (bounds.height - barHeight) / 2
      let rect = NSRect(x: x, y: y, width: barWidth, height: barHeight)
      NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5).fill()
      x += barWidth + spacing
    }
  }
  
  deinit {
    animTimer?.invalidate()
  }
}
