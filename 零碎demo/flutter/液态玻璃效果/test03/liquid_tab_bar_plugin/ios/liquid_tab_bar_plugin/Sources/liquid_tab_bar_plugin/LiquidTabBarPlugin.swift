import Flutter
import UIKit

/// 插件由 Flutter 自动注册，消费 App 不需要修改 AppDelegate。
public final class LiquidTabBarPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let factory = NativeLiquidTabBarFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: NativeLiquidTabBarFactory.viewType)
  }
}

private final class NativeLiquidTabBarFactory: NSObject, FlutterPlatformViewFactory {
  static let viewType = "com.example.liquid_tab_bar"

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

private final class NativeLiquidTabBarPlatformView: NSObject, FlutterPlatformView {
  private let hostView: NativeLiquidTabBarHostView
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?,
    binaryMessenger messenger: FlutterBinaryMessenger
  ) {
    let values = args as? [String: Any]
    let selectedIndex = (values?["selectedIndex"] as? NSNumber)?.intValue ?? 0
    let collapsed = (values?["collapsed"] as? NSNumber)?.boolValue ?? false
    let revision = (values?["revision"] as? NSNumber)?.int64Value ?? 0
    let items = Self.decodeItems(values?["destinations"])

    hostView = NativeLiquidTabBarHostView(
      frame: frame,
      items: items,
      selectedIndex: selectedIndex,
      collapsed: collapsed,
      revision: revision
    )
    channel = FlutterMethodChannel(
      name: "com.example.liquid_tab_bar/\(viewId)",
      binaryMessenger: messenger
    )

    super.init()

    hostView.onTabSelected = { [weak self] index in
      self?.channel.invokeMethod("tabSelected", arguments: index)
    }

    channel.setMethodCallHandler { [weak self] call, result in
      // UIKit 的状态更新全部回到主线程。
      DispatchQueue.main.async { [weak self] in
        guard let self else {
          result(FlutterError(
            code: "view_disposed",
            message: "LiquidTabBar 已销毁",
            details: nil
          ))
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

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "collapse", "expand":
      guard
        let values = call.arguments as? [String: Any],
        let revision = (values["revision"] as? NSNumber)?.int64Value
      else {
        result(FlutterError(
          code: "bad_arguments",
          message: "collapse / expand 需要 revision",
          details: nil
        ))
        return
      }

      hostView.setCollapsed(call.method == "collapse", revision: revision, animated: true)
      result(nil)

    case "setSelected":
      guard
        let values = call.arguments as? [String: Any],
        let index = (values["index"] as? NSNumber)?.intValue
      else {
        result(FlutterError(
          code: "bad_arguments",
          message: "setSelected 需要 index",
          details: nil
        ))
        return
      }

      hostView.setSelectedIndex(index)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func decodeItems(_ rawItems: Any?) -> [NativeTabItem] {
    let values = rawItems as? [[String: Any]] ?? []
    let items = values.compactMap { value -> NativeTabItem? in
      guard
        let label = value["label"] as? String,
        let id = value["id"] as? String,
        let symbol = value["iosSymbolName"] as? String
      else {
        return nil
      }
      return NativeTabItem(
        id: id,
        label: label,
        symbol: symbol,
        selectedSymbol: value["selectedIosSymbolName"] as? String ?? symbol
      )
    }

    // Dart 侧已经限制 2–5 个；这里仍保留安全默认值，避免坏参数导致空白控件。
    return items.count >= 2 && items.count <= 5
      ? items
      : [
          NativeTabItem(
            id: "home", label: "首页", symbol: "house", selectedSymbol: "house.fill"
          ),
          NativeTabItem(
            id: "profile", label: "我的", symbol: "person", selectedSymbol: "person.fill"
          ),
        ]
  }
}

private struct NativeTabItem {
  let id: String
  let label: String
  let symbol: String
  let selectedSymbol: String
}

/// 返回给 Flutter 的宿主尺寸固定，动画只作用于内部 surfaceView。
private final class NativeLiquidTabBarHostView: UIView {
  private let compactScale: CGFloat = 0.88

  private let surfaceView = UIView()
  private let opaqueBackdrop = UIView()
  private let materialView: UIVisualEffectView
  private var animator: UIViewPropertyAnimator?

  private var selectedIndex: Int
  private var isCollapsed: Bool
  private var lastRevision: Int64
  private var buttons: [UIButton] = []
  private let items: [NativeTabItem]

  var onTabSelected: ((Int) -> Void)?

  init(
    frame: CGRect,
    items: [NativeTabItem],
    selectedIndex: Int,
    collapsed: Bool,
    revision: Int64
  ) {
    materialView = UIVisualEffectView(effect: Self.makeMaterialEffect())
    self.items = items
    self.selectedIndex = min(max(selectedIndex, 0), items.count - 1)
    isCollapsed = collapsed
    lastRevision = revision

    super.init(frame: frame)

    backgroundColor = .clear
    isOpaque = false
    clipsToBounds = false

    configureSurface()
    configureButtons(items: items)
    applySelection()
    refreshMaterial(animated: false)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(reduceTransparencyChanged),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil
    )
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    animator?.stopAnimation(true)
    NotificationCenter.default.removeObserver(self)
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    // 低版本没有 cornerConfiguration，圆角随实际高度更新。
    if #unavailable(iOS 26.0) {
      let radius = materialView.bounds.height / 2
      opaqueBackdrop.layer.cornerRadius = radius
      materialView.layer.cornerRadius = radius
    }

    // 尺寸变化后，重新计算收起状态的底边锚定位置。
    guard isCollapsed else {
      return
    }
    UIView.performWithoutAnimation {
      surfaceView.transform = transform(for: compactScale)
    }
  }

  func setCollapsed(_ collapsed: Bool, revision: Int64, animated: Bool) {
    // 旧消息晚到时直接丢弃，避免视觉状态倒退。
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

    // 新命令可打断旧动画，但不触碰 Flutter Platform View 根节点。
    animator?.stopAnimation(true)
    animator = nil

    guard animated, !UIAccessibility.isReduceMotionEnabled else {
      UIView.performWithoutAnimation {
        self.surfaceView.transform = targetTransform
      }
      return
    }

    let nextAnimator = UIViewPropertyAnimator(
      duration: 0.28,
      curve: .easeOut
    ) { [weak self] in
      self?.surfaceView.transform = targetTransform
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

  /// Dart 路由提交最终的选中结果后才调用这里。
  ///
  /// UIKit 点击本身不会提前修改 selectedIndex。这样当 Flutter 因权限、
  /// 重定向等原因没有切换路由时，原生控件不会留下错误的高亮状态。
  func setSelectedIndex(_ index: Int) {
    guard buttons.indices.contains(index), selectedIndex != index else {
      return
    }

    selectedIndex = index
    applySelection()
  }

  private static func makeMaterialEffect() -> UIVisualEffect {
    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(style: .regular)
      effect.isInteractive = true
      return effect
    }
    return UIBlurEffect(style: .systemMaterial)
  }

  private func configureSurface() {
    surfaceView.translatesAutoresizingMaskIntoConstraints = false
    opaqueBackdrop.translatesAutoresizingMaskIntoConstraints = false
    materialView.translatesAutoresizingMaskIntoConstraints = false
    opaqueBackdrop.backgroundColor = .secondarySystemBackground

    addSubview(surfaceView)
    surfaceView.addSubview(opaqueBackdrop)
    surfaceView.addSubview(materialView)

    NSLayoutConstraint.activate([
      surfaceView.leadingAnchor.constraint(equalTo: leadingAnchor),
      surfaceView.trailingAnchor.constraint(equalTo: trailingAnchor),
      surfaceView.topAnchor.constraint(equalTo: topAnchor),
      surfaceView.bottomAnchor.constraint(equalTo: bottomAnchor),
      opaqueBackdrop.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor),
      opaqueBackdrop.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor),
      opaqueBackdrop.topAnchor.constraint(equalTo: surfaceView.topAnchor),
      opaqueBackdrop.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor),
      materialView.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor),
      materialView.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor),
      materialView.topAnchor.constraint(equalTo: surfaceView.topAnchor),
      materialView.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor),
    ])

    if #available(iOS 26.0, *) {
      materialView.cornerConfiguration = .capsule()
      opaqueBackdrop.cornerConfiguration = .capsule()
    } else {
      materialView.layer.cornerCurve = .continuous
      materialView.clipsToBounds = true
    }
    opaqueBackdrop.layer.cornerCurve = .continuous
    opaqueBackdrop.clipsToBounds = true
  }

  private func configureButtons(items: [NativeTabItem]) {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.alignment = .fill
    stack.translatesAutoresizingMaskIntoConstraints = false
    materialView.contentView.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: materialView.contentView.leadingAnchor, constant: 8),
      stack.trailingAnchor.constraint(equalTo: materialView.contentView.trailingAnchor, constant: -8),
      stack.topAnchor.constraint(equalTo: materialView.contentView.topAnchor, constant: 4),
      stack.bottomAnchor.constraint(equalTo: materialView.contentView.bottomAnchor, constant: -4),
    ])

    for (index, item) in items.enumerated() {
      var configuration = UIButton.Configuration.plain()
      configuration.title = item.label
      configuration.image = UIImage(systemName: item.symbol)
      configuration.imagePlacement = .top
      configuration.imagePadding = 4
      configuration.contentInsets = NSDirectionalEdgeInsets(
        top: 6, leading: 4, bottom: 6, trailing: 4
      )

      let button = UIButton(type: .system)
      button.configuration = configuration
      button.tag = index
      button.accessibilityIdentifier = "liquid_tab_\(item.id)"
      button.addTarget(self, action: #selector(didTapTab(_:)), for: .touchUpInside)
      buttons.append(button)
      stack.addArrangedSubview(button)
    }
  }

  private func refreshMaterial(animated: Bool) {
    let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled
    opaqueBackdrop.isHidden = !reduceTransparency
    let nextEffect: UIVisualEffect? = reduceTransparency ? nil : Self.makeMaterialEffect()
    let changes = { self.materialView.effect = nextEffect }

    guard animated, !UIAccessibility.isReduceMotionEnabled else {
      UIView.performWithoutAnimation(changes)
      return
    }
    UIView.animate(withDuration: 0.2, animations: changes)
  }

  private func applySelection() {
    for (index, button) in buttons.enumerated() {
      let selected = index == selectedIndex
      var configuration = button.configuration
      configuration?.baseForegroundColor = selected ? .systemBlue : .secondaryLabel
      configuration?.image = UIImage(
        systemName: selected ? items[index].selectedSymbol : items[index].symbol
      )
      button.configuration = configuration
      button.accessibilityTraits = selected ? [.button, .selected] : [.button]
      button.accessibilityValue = selected ? "当前标签" : nil
    }
  }

  private func transform(for scale: CGFloat) -> CGAffineTransform {
    // 中心缩放后向下补偿，视觉底边保持不动。
    let offsetY = surfaceView.bounds.height * (1 - scale) / 2
    return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: 0, ty: offsetY)
  }

  @objc
  private func didTapTab(_ sender: UIButton) {
    // 原生侧只提出选择请求；选中态由 Dart 路由的 selectedIndex 回灌。
    onTabSelected?(sender.tag)
  }

  @objc
  private func reduceTransparencyChanged() {
    refreshMaterial(animated: window != nil)
  }
}
