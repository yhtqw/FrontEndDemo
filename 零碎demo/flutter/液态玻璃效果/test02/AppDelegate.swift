// ios/Runner/AppDelegate.swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(
    _ engineBridge: FlutterImplicitEngineBridge
  ) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "NativeLiquidTabBar"
    ) else {
      return
    }

    let factory = NativeLiquidTabBarFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: NativeLiquidTabBarFactory.viewType)
  }
}

final class NativeLiquidTabBarFactory: NSObject, FlutterPlatformViewFactory {
  static let viewType = "com.example.native_liquid_tab_bar"

  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NativeLiquidTabBarPlatformView(
      frame: frame,
      viewIdentifier: viewId,
      arguments: args,
      binaryMessenger: messenger
    )
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class NativeLiquidTabBarPlatformView: NSObject, FlutterPlatformView {
  private let hostView: NativeLiquidTabBarHostView
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?,
    binaryMessenger messenger: FlutterBinaryMessenger
  ) {
    let values = args as? [String: Any]
    let selectedIndex =
      (values?["selectedIndex"] as? NSNumber)?.intValue ?? 0
    let initiallyCollapsed =
      (values?["collapsed"] as? NSNumber)?.boolValue ?? false
    let initialRevision =
      (values?["revision"] as? NSNumber)?.int64Value ?? 0

    hostView = NativeLiquidTabBarHostView(
      frame: frame,
      selectedIndex: selectedIndex,
      collapsed: initiallyCollapsed,
      revision: initialRevision
    )

    channel = FlutterMethodChannel(
      name: "com.example.native_liquid_tab_bar/\(viewId)",
      binaryMessenger: messenger
    )

    super.init()

    hostView.onTabSelected = { [weak self] index in
      self?.channel.invokeMethod("tabSelected", arguments: index)
    }

    channel.setMethodCallHandler { [weak self] call, result in
      // UIKit 更新统一回到主线程执行。
      DispatchQueue.main.async { [weak self] in
        guard let self else {
          result(
            FlutterError(
              code: "view_disposed",
              message: "原生 TabBar 已销毁",
              details: nil
            )
          )
          return
        }

        self.handle(call, result: result)
      }
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView {
    hostView
  }

  private func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "collapse", "expand":
      guard
        let values = call.arguments as? [String: Any],
        let revision =
          (values["revision"] as? NSNumber)?.int64Value
      else {
        result(
          FlutterError(
            code: "bad_arguments",
            message: "collapse / expand 需要 revision",
            details: nil
          )
        )
        return
      }

      hostView.setCollapsed(
        call.method == "collapse",
        revision: revision,
        animated: true
      )
      result(nil)

    case "setSelected":
      guard
        let values = call.arguments as? [String: Any],
        let index =
          (values["index"] as? NSNumber)?.intValue
      else {
        result(
          FlutterError(
            code: "bad_arguments",
            message: "setSelected 需要 index",
            details: nil
          )
        )
        return
      }

      hostView.setSelectedIndex(index, notifyFlutter: false)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// 固定尺寸的 Platform View 宿主；真正变化的是内部 glassView。
final class NativeLiquidTabBarHostView: UIView {
  private let compactScale: CGFloat = 0.88

  private let glassView: UIVisualEffectView
  private var animator: UIViewPropertyAnimator?

  private var selectedIndex: Int
  private var isCollapsed: Bool
  private var lastRevision: Int64
  private var buttons: [UIButton] = []

  var onTabSelected: ((Int) -> Void)?

  init(
    frame: CGRect,
    selectedIndex: Int,
    collapsed: Bool,
    revision: Int64
  ) {
    let glassEffect = UIGlassEffect(style: .regular)
    glassEffect.isInteractive = true

    glassView = UIVisualEffectView(effect: glassEffect)
    self.selectedIndex = min(max(selectedIndex, 0), 2)
    isCollapsed = collapsed
    lastRevision = revision

    super.init(frame: frame)

    backgroundColor = .clear
    isOpaque = false
    clipsToBounds = false

    configureGlassView()
    configureButtons()
    applySelection()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    // 尺寸变化后，重新计算收起状态的底部锚定位置。
    guard isCollapsed else {
      return
    }

    UIView.performWithoutAnimation {
      glassView.transform = transform(for: compactScale)
    }
  }

  deinit {
    animator?.stopAnimation(true)
  }

  func setCollapsed(
    _ collapsed: Bool,
    revision: Int64,
    animated: Bool
  ) {
    // 旧消息晚到时直接忽略，避免视觉状态倒退。
    guard revision > lastRevision else {
      return
    }

    lastRevision = revision

    guard collapsed != isCollapsed else {
      return
    }

    isCollapsed = collapsed
    layoutIfNeeded()

    let scale: CGFloat = collapsed ? compactScale : 1
    let targetTransform = transform(for: scale)

    // 新意图先停掉旧动画，并保留当前显示位置。
    animator?.stopAnimation(true)
    animator = nil

    guard animated, !UIAccessibility.isReduceMotionEnabled else {
      UIView.performWithoutAnimation {
        self.glassView.transform = targetTransform
      }
      return
    }

    let nextAnimator = UIViewPropertyAnimator(
      duration: 0.28,
      curve: .easeOut
    ) { [weak self] in
      // 只变换内部玻璃卡片，不触碰 Flutter Platform View 根节点。
      self?.glassView.transform = targetTransform
    }

    nextAnimator.isInterruptible = true
    nextAnimator.isUserInteractionEnabled = true

    nextAnimator.addCompletion { [weak self, weak nextAnimator] _ in
      guard let self, self.animator === nextAnimator else {
        return
      }

      self.animator = nil
    }

    animator = nextAnimator
    nextAnimator.startAnimation()
  }

  func setSelectedIndex(_ index: Int, notifyFlutter: Bool) {
    guard buttons.indices.contains(index), selectedIndex != index else {
      return
    }

    selectedIndex = index
    applySelection()

    if notifyFlutter {
      onTabSelected?(index)
    }
  }

  private func configureGlassView() {
    glassView.translatesAutoresizingMaskIntoConstraints = false
    glassView.cornerConfiguration = .capsule()

    addSubview(glassView)

    NSLayoutConstraint.activate([
      glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
      glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
      glassView.topAnchor.constraint(equalTo: topAnchor),
      glassView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  private func configureButtons() {
    let tabs: [(title: String, symbol: String)] = [
      ("首页", "house.fill"),
      ("灵感", "sparkles"),
      ("我的", "person.fill"),
    ]

    let stack = UIStackView()
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.alignment = .fill
    stack.translatesAutoresizingMaskIntoConstraints = false

    glassView.contentView.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(
        equalTo: glassView.contentView.leadingAnchor,
        constant: 8
      ),
      stack.trailingAnchor.constraint(
        equalTo: glassView.contentView.trailingAnchor,
        constant: -8
      ),
      stack.topAnchor.constraint(
        equalTo: glassView.contentView.topAnchor,
        constant: 4
      ),
      stack.bottomAnchor.constraint(
        equalTo: glassView.contentView.bottomAnchor,
        constant: -4
      ),
    ])

    for (index, tab) in tabs.enumerated() {
      var configuration = UIButton.Configuration.plain()
      configuration.title = tab.title
      configuration.image = UIImage(systemName: tab.symbol)
      configuration.imagePlacement = .top
      configuration.imagePadding = 4
      configuration.contentInsets = NSDirectionalEdgeInsets(
        top: 6,
        leading: 4,
        bottom: 6,
        trailing: 4
      )

      let button = UIButton(type: .system)
      button.configuration = configuration
      button.tag = index
      button.accessibilityIdentifier = "native_tab_\(index)"
      button.addTarget(
        self,
        action: #selector(didTapTab(_:)),
        for: .touchUpInside
      )

      buttons.append(button)
      stack.addArrangedSubview(button)
    }
  }

  private func applySelection() {
    for (index, button) in buttons.enumerated() {
      let selected = index == selectedIndex

      var configuration = button.configuration
      configuration?.baseForegroundColor =
        selected ? .systemBlue : .secondaryLabel
      button.configuration = configuration

      button.accessibilityTraits =
        selected ? [.button, .selected] : [.button]
      button.accessibilityValue = selected ? "当前标签" : nil
    }
  }

  private func transform(for scale: CGFloat) -> CGAffineTransform {
    // 默认围绕中心缩放；补偿下半段高度，让视觉底边保持不动。
    let offsetY = glassView.bounds.height * (1 - scale) / 2

    return CGAffineTransform(
      a: scale,
      b: 0,
      c: 0,
      d: scale,
      tx: 0,
      ty: offsetY
    )
  }

  @objc
  private func didTapTab(_ sender: UIButton) {
    setSelectedIndex(sender.tag, notifyFlutter: true)
  }
}
