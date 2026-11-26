import Cocoa
import FlutterMacOS
import window_manager

/// A top-left-origin host for native glass surfaces. It lives behind Flutter's
/// transparent Metal surface and never participates in hit testing.
private final class NativeGlassHostView: NSView {
  var onLayout: ((NSSize) -> Void)?

  override var isFlipped: Bool { true }
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func layout() {
    super.layout()
    onLayout?(bounds.size)
  }
}

private final class NativeGlassSurfaceView: NSView {
  private struct SurfaceConfig: Equatable {
    let material: String
    let radius: CGFloat
    let opacity: CGFloat
    let frost: CGFloat
    let clearStyle: Bool
    let interactive: Bool
    let tintHex: Int?
    let innerFrame: NSRect
  }

  private var fallbackEffectView: NSVisualEffectView?
  private var frostEffectView: NSVisualEffectView?
  private var modernGlassStorage: AnyObject?
  private let reduceTransparencyLayer = CALayer()
  private var lastConfig: SurfaceConfig?

  override var isFlipped: Bool { true }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    if #available(macOS 14.0, *) {
      clipsToBounds = true
    }
    wantsLayer = true
    layer?.masksToBounds = true
    layer?.backgroundColor = NSColor.clear.cgColor
    reduceTransparencyLayer.isHidden = true
    reduceTransparencyLayer.masksToBounds = true
    reduceTransparencyLayer.cornerCurve = .continuous
    layer?.addSublayer(reduceTransparencyLayer)

    if #available(macOS 26.0, *) {
      let glass = NSGlassEffectView(frame: bounds)
      glass.style = .regular
      glass.wantsLayer = true
      modernGlassStorage = glass
      addSubview(glass)
    } else {
      let effect = NSVisualEffectView(frame: bounds)
      effect.blendingMode = .behindWindow
      effect.state = .active
      effect.wantsLayer = true
      effect.layer?.masksToBounds = true
      effect.layer?.cornerCurve = .continuous
      fallbackEffectView = effect
      addSubview(effect)
    }
  }

  required init?(coder: NSCoder) { nil }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  func update(
    material: String,
    radius: CGFloat,
    opacity: CGFloat,
    frost: CGFloat,
    clearStyle: Bool,
    interactive: Bool,
    tintHex: Int?,
    innerFrame: NSRect
  ) {
    let config = SurfaceConfig(
      material: material,
      radius: radius,
      opacity: opacity,
      frost: frost,
      clearStyle: clearStyle,
      interactive: interactive,
      tintHex: tintHex,
      innerFrame: innerFrame
    )
    if config == lastConfig { return }
    lastConfig = config
    apply(config)
  }

  func refreshEnvironment() {
    guard let config = lastConfig else { return }
    apply(config)
  }

  private static func resolvedVisualEffectMaterial(_ material: String) -> NSVisualEffectView.Material {
    switch material {
    case "sidebar": return .sidebar
    case "popover": return .popover
    case "menu": return .menu
    case "underWindow": return .underWindowBackground
    default: return .hudWindow
    }
  }

  private func apply(_ config: SurfaceConfig) {
    let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    defer { CATransaction.commit() }

    if #available(macOS 14.0, *) {
      clipsToBounds = true
    }
    wantsLayer = true
    layer?.masksToBounds = true
    layer?.contentsScale = scale

    if #available(macOS 26.0, *), let glass = modernGlassStorage as? NSGlassEffectView {
      glass.frame = config.innerFrame
      glass.cornerRadius = config.radius
      glass.style = config.clearStyle ? .clear : .regular
      glass.layer?.contentsScale = scale
      if let tintHex = config.tintHex {
        glass.tintColor = Self.colorFromArgb(tintHex)
      } else {
        glass.tintColor = nil
      }
      if #available(macOS 27.0, *) {
        glass.effectIsInteractive = config.interactive
      }
      let clampedFrost = min(max(config.frost, 0.0), 1.0)
      if !reduceTransparency && clampedFrost > 0.001 {
        let frostView = frostEffectView ?? {
          let effect = NSVisualEffectView(frame: config.innerFrame)
          effect.blendingMode = .behindWindow
          effect.state = .active
          effect.wantsLayer = true
          effect.layer?.masksToBounds = true
          effect.layer?.cornerCurve = .continuous
          frostEffectView = effect
          addSubview(effect, positioned: .above, relativeTo: glass)
          return effect
        }()
        frostView.isHidden = false
        frostView.frame = config.innerFrame
        frostView.material = Self.resolvedVisualEffectMaterial(config.material)
        frostView.layer?.cornerRadius = config.radius
        frostView.layer?.cornerCurve = .continuous
        frostView.layer?.contentsScale = scale
        frostView.alphaValue = clampedFrost * 0.62
      } else {
        frostEffectView?.isHidden = true
      }
      applyReduceTransparency(config, scale: scale, primaryView: glass, enabled: reduceTransparency)
      return
    }

    if let effect = fallbackEffectView {
      effect.frame = config.innerFrame
      effect.material = Self.resolvedVisualEffectMaterial(config.material)
      effect.layer?.cornerRadius = config.radius
      effect.layer?.cornerCurve = .continuous
      effect.layer?.masksToBounds = true
      effect.layer?.contentsScale = scale
      effect.alphaValue = max(0.35, min(config.opacity + min(max(config.frost, 0.0), 1.0) * 0.25, 1.0))

      applyReduceTransparency(config, scale: scale, primaryView: effect, enabled: reduceTransparency)
    }
  }

  private func applyReduceTransparency(
    _ config: SurfaceConfig,
    scale: CGFloat,
    primaryView: NSView,
    enabled: Bool
  ) {
    layer?.cornerRadius = 0
    layer?.backgroundColor = NSColor.clear.cgColor
    if enabled {
      primaryView.isHidden = true
      reduceTransparencyLayer.isHidden = false
      reduceTransparencyLayer.frame = config.innerFrame
      reduceTransparencyLayer.cornerRadius = config.radius
      reduceTransparencyLayer.contentsScale = scale
      var resolvedBg = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
      let appearance = window?.effectiveAppearance ?? effectiveAppearance
      appearance.performAsCurrentDrawingAppearance {
        resolvedBg = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
      }
      reduceTransparencyLayer.backgroundColor = resolvedBg
    } else {
      primaryView.isHidden = false
      reduceTransparencyLayer.isHidden = true
    }
  }

  private static func colorFromArgb(_ argb: Int) -> NSColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
  }
}

/// Owns stable AppKit material views requested by Flutter. Views are updated in
/// place instead of being recreated during widget rebuilds.
private final class NativeGlassSurfaceManager {
  private weak var window: NSWindow?
  private let hostView: NativeGlassHostView
  private var surfaces: [String: NativeGlassSurfaceView] = [:]
  private var channel: FlutterMethodChannel?
  private var windowObservers: [NSObjectProtocol] = []
  private var workspaceObservers: [NSObjectProtocol] = []

  init(window: NSWindow, hostView: NativeGlassHostView, messenger: FlutterBinaryMessenger) {
    self.window = window
    self.hostView = hostView

    channel = FlutterMethodChannel(name: "dropit/native_glass", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      if Thread.isMainThread {
        self?.handle(call, result: result)
      } else {
        DispatchQueue.main.async {
          self?.handle(call, result: result)
        }
      }
    }

    let nc = NotificationCenter.default
    let windowNotifications: [Notification.Name] = [
      NSWindow.didResizeNotification,
      NSWindow.didEndLiveResizeNotification,
      NSWindow.didChangeScreenNotification,
      NSWindow.didChangeBackingPropertiesNotification,
      NSWindow.didDeminiaturizeNotification,
      NSWindow.didBecomeKeyNotification,
    ]
    for name in windowNotifications {
      let token = nc.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
        self?.handleEnvironmentChange(notifyFlutter: name != NSWindow.didBecomeKeyNotification)
      }
      windowObservers.append(token)
    }

    let wsToken = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.handleEnvironmentChange(notifyFlutter: true)
    }
    workspaceObservers.append(wsToken)
  }

  deinit {
    let nc = NotificationCenter.default
    for token in windowObservers {
      nc.removeObserver(token)
    }
    let wsNc = NSWorkspace.shared.notificationCenter
    for token in workspaceObservers {
      wsNc.removeObserver(token)
    }
  }

  private func handleEnvironmentChange(notifyFlutter: Bool) {
    for surface in surfaces.values {
      surface.refreshEnvironment()
    }
    hostView.needsDisplay = true
    if notifyFlutter {
      channel?.invokeMethod("invalidateSurfaces", arguments: nil)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setSurface":
      guard
        let args = call.arguments as? [String: Any],
        let id = args["id"] as? String,
        let x = args["x"] as? Double,
        let y = args["y"] as? Double,
        let width = args["width"] as? Double,
        let height = args["height"] as? Double
      else {
        result(FlutterError(code: "invalid_surface", message: "Invalid native glass surface arguments", details: nil))
        return
      }

      let clipX = (args["clipX"] as? Double) ?? x
      let clipY = (args["clipY"] as? Double) ?? y
      let clipWidth = (args["clipWidth"] as? Double) ?? width
      let clipHeight = (args["clipHeight"] as? Double) ?? height
      guard
        x.isFinite, y.isFinite, width.isFinite, height.isFinite,
        clipX.isFinite, clipY.isFinite, clipWidth.isFinite, clipHeight.isFinite
      else {
        result(true)
        return
      }
      let fullRect = NSRect(x: x, y: y, width: max(0, width), height: max(0, height))
      let clipRect = NSRect(
        x: clipX,
        y: clipY,
        width: max(0, clipWidth),
        height: max(0, clipHeight)
      )
      let innerFrame = NSRect(
        x: fullRect.minX - clipRect.minX,
        y: fullRect.minY - clipRect.minY,
        width: fullRect.width,
        height: fullRect.height
      )

      let surface = surfaces[id] ?? {
        let view = NativeGlassSurfaceView(frame: .zero)
        surfaces[id] = view
        hostView.addSubview(view)
        return view
      }()
      let rawRadius = args["radius"] as? Double ?? 24
      let clampedRadius = max(0, min(rawRadius, min(fullRect.width, fullRect.height) * 0.5))
      let visible = (args["visible"] as? Bool ?? true) && clipRect.width > 0.5 && clipRect.height > 0.5

      CATransaction.begin()
      CATransaction.setDisableActions(true)
      if surface.frame != clipRect {
        surface.frame = clipRect
      }
      surface.update(
        material: args["material"] as? String ?? "hud",
        radius: clampedRadius,
        opacity: args["opacity"] as? Double ?? 0.9,
        frost: args["frost"] as? Double ?? 0.0,
        clearStyle: args["clear"] as? Bool ?? false,
        interactive: args["interactive"] as? Bool ?? false,
        tintHex: args["tintArgb"] as? Int,
        innerFrame: innerFrame
      )
      if surface.isHidden != !visible {
        surface.isHidden = !visible
      }
      CATransaction.commit()
      result(true)

    case "setAppearance":
      let mode = (call.arguments as? [String: Any])?["appearance"] as? String ?? "system"
      let resolved: NSAppearance? = switch mode {
      case "dark": NSAppearance(named: .darkAqua)
      case "light": NSAppearance(named: .aqua)
      default: nil
      }
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      window?.appearance = resolved
      hostView.appearance = resolved
      for surface in surfaces.values {
        surface.refreshEnvironment()
      }
      CATransaction.commit()
      result(nil)

    case "removeSurface":
      if let id = (call.arguments as? [String: Any])?["id"] as? String {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        surfaces.removeValue(forKey: id)?.removeFromSuperview()
        CATransaction.commit()
      }
      result(nil)

    case "clearSurfaces":
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      for surface in surfaces.values { surface.removeFromSuperview() }
      surfaces.removeAll()
      CATransaction.commit()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

class MainFlutterWindow: NSWindow {
  private(set) var flutterViewController: FlutterViewController!
  private var nativeGlassManager: NativeGlassSurfaceManager?

  override func awakeFromNib() {
    let flutterController = FlutterViewController()
    flutterViewController = flutterController

    let windowFrame = frame
    let containerController = NSViewController()
    let containerView = NSView(frame: windowFrame)
    containerView.wantsLayer = true
    containerView.layer?.backgroundColor = NSColor.clear.cgColor
    containerController.view = containerView
    containerController.addChild(flutterController)

    let nativeGlassHost = NativeGlassHostView(frame: containerView.bounds)
    nativeGlassHost.translatesAutoresizingMaskIntoConstraints = false
    flutterController.view.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(nativeGlassHost)
    containerView.addSubview(flutterController.view)
    NSLayoutConstraint.activate([
      nativeGlassHost.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      nativeGlassHost.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      nativeGlassHost.topAnchor.constraint(equalTo: containerView.topAnchor),
      nativeGlassHost.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
      flutterController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      flutterController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      flutterController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
      flutterController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
    ])

    contentViewController = containerController
    setFrame(windowFrame, display: true)

    // Preserve Flutter alpha all the way to the WindowServer compositor.
    // Disable NSWindow's global alpha-silhouette shadow because NSGlassEffectView
    // renders its own optical shadows; keeping hasShadow = true causes
    // WindowServer to quantize soft Flutter blur/text halos into dark outlines.
    isOpaque = false
    backgroundColor = .clear
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
    styleMask.insert(.fullSizeContentView)
    hasShadow = false
    flutterController.backgroundColor = .clear
    flutterController.view.wantsLayer = true
    flutterController.view.layer?.backgroundColor = NSColor.clear.cgColor

    RegisterGeneratedPlugins(registry: flutterController)
    nativeGlassManager = NativeGlassSurfaceManager(
      window: self,
      hostView: nativeGlassHost,
      messenger: flutterController.engine.binaryMessenger
    )

    super.awakeFromNib()
  }

  // window_manager: start hidden
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
