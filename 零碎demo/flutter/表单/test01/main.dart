import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const DropdownApp());

class Brand {
  const Brand(this.id, this.name);
  final String id;
  final String name;
}

const brands = <Brand>[
  Brand('huawei', '华为'),
  Brand('xiaomi', '小米'),
  Brand('apple', 'Apple'),
  Brand('honor', '荣耀'),
  Brand('oppo', 'OPPO'),
  Brand('vivo', 'vivo'),
  Brand('samsung', '三星'),
  Brand('lenovo', '联想'),
  Brand('sony', '索尼'),
  Brand('canon', '佳能'),
  Brand('nikon', '尼康'),
  Brand('dji', '大疆'),
];

Future<List<Brand>> searchBrands(String query) async {
  // 模拟接口延迟，故意让短查询更慢，便于验证乱序。
  await Future<void>.delayed(
    Duration(milliseconds: query.length == 1 ? 650 : 200),
  );
  
  if (query == 'fail') throw StateError('模拟网络失败');
  
  final keyword = query.trim().toLowerCase();
  
  return brands.where((b) => b.name.toLowerCase().contains(keyword)).toList();
}

class DropdownApp extends StatelessWidget {
  const DropdownApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff256b59)),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: const FilterPage(),
  );
}

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  final _form = GlobalKey<FormState>();
  Set<String> _saved = {};
  String _result = '全部品牌';

  void _submit() {
    if (!_form.currentState!.validate()) return;
    
    _form.currentState!.save();
    
    setState(() {
      _result = brands
          .where((b) => _saved.contains(b.id))
          .map((b) => b.name)
          .join('、');
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('商品筛选')),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  '商品条件',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  decoration: const InputDecoration(labelText: '商品名称'),
                ),
                const SizedBox(height: 24),
                FormField<Set<String>>(
                  initialValue: const {},
                  validator: (value) =>
                      value == null || value.isEmpty ? '请选择至少一个品牌' : null,
                  onSaved: (value) => _saved = Set.of(value ?? const {}),
                  builder: (field) => BrandPicker(
                    catalog: brands,
                    search: searchBrands,
                    value: field.value ?? const {},
                    onChanged: field.didChange,
                    errorText: field.errorText,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('price'),
                  decoration: const InputDecoration(labelText: '最高价格'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('查询'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () {
                        _form.currentState!.reset();
                        setState(() => _result = '全部品牌');
                      },
                      child: const Text('重置'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(_result),
                  ),
                ),
                const SizedBox(height: 240),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class MenuPlacement {
  const MenuPlacement(this.rect, this.upward);
  final Rect rect;
  final bool upward;
}

MenuPlacement placeMenu(
  Rect anchor,
  Rect visible, {
  double desiredHeight = 320,
  bool rtl = false,
}) {
  const gap = 6.0;
  final below = math.max(0.0, visible.bottom - anchor.bottom - gap);
  final above = math.max(0.0, anchor.top - visible.top - gap);
  final upward = below < desiredHeight && above > below;
  final height = math.min(desiredHeight, upward ? above : below);
  final width = math.min(math.max(anchor.width, 280.0), visible.width);
  final left = (rtl ? anchor.right - width : anchor.left)
      .clamp(visible.left, visible.right - width)
      .toDouble();
  final top = upward ? anchor.top - gap - height : anchor.bottom + gap;
  
  return MenuPlacement(Rect.fromLTWH(left, top, width, height), upward);
}

class BrandPicker extends StatefulWidget {
  const BrandPicker({
    super.key,
    required this.catalog,
    required this.search,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final List<Brand> catalog;
  final Future<List<Brand>> Function(String query) search;
  final Set<String> value;
  final ValueChanged<Set<String>> onChanged;
  final String? errorText;

  @override
  State<BrandPicker> createState() => _BrandPickerState();
}

class _BrandPickerState extends State<BrandPicker> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _portal = OverlayPortalController();
  final _triggerFocus = FocusNode();
  final _searchFocus = FocusNode();
  final _searchText = TextEditingController();
  final _listScroll = ScrollController();
  final _tapGroup = Object();
  late final AnimationController _animation;
  late final Animation<double> _curve;
  Timer? _debounce;
  List<Brand> _results = const [];
  int _revision = 0;
  int _highlight = 0;
  bool _open = false;
  bool _loading = false;
  bool _failed = false;
  bool _layoutCloseQueued = false;
  double _rowHeight = 48;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
          reverseDuration: const Duration(milliseconds: 120),
        )..addStatusListener((status) {
          // 只认当前状态，旧的关闭动作不能移除重新打开的菜单。
          if (status == AnimationStatus.dismissed && !_open) _portal.hide();
        });
    _curve = _animation.drive(CurveTween(curve: Curves.easeOutCubic));
    _searchText.addListener(_onEdit);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _revision++;
    _searchText.dispose();
    _searchFocus.dispose();
    _triggerFocus.dispose();
    _listScroll.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // 使用窗口原始 inset，窗口变化时让浮层重新布局。
    if (mounted && _portal.isShowing) setState(() {});
  }

  void _show() {
    if (_open) return;
    
    _searchText.clear();
    setState(() => _open = true);
    _portal.show();
    _fetch('', ++_revision);
    
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else {
      _animation.forward();
    }
    
    // 搜索框挂载后再请求焦点，避免请求丢失。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) _searchFocus.requestFocus();
    });
  }

  void _close({bool restoreFocus = false}) {
    if (!_open) return;
    
    _debounce?.cancel();
    _revision++;
    setState(() => _open = false);
    
    if (_searchFocus.hasFocus) _searchFocus.unfocus();
    if (restoreFocus) _triggerFocus.requestFocus();
    if (MediaQuery.disableAnimationsOf(context) || _animation.value == 0) {
      _animation.value = 0;
      _portal.hide();
    } else {
      _animation.reverse();
    }
  }

  void _queueLayoutClose() {
    if (_layoutCloseQueued) return;
    
    _layoutCloseQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutCloseQueued = false;
      if (mounted && _open) _close();
    });
  }

  void _onEdit() {
    _debounce?.cancel();
    final ticket = ++_revision; // 输入一变就作废旧请求，不能等防抖结束。
    
    if (!_open) return;
    
    final editing = _searchText.value;
    
    if (!editing.composing.isCollapsed) return;
    
    setState(() {
      _loading = true;
      _failed = false;
      _results = const [];
      _highlight = 0;
    });
   
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _fetch(editing.text, ticket),
    );
  }

  Future<void> _fetch(String query, int ticket) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    
    try {
      final result = await widget.search(query);
      
      if (!mounted || !_open || ticket != _revision) return;
      
      setState(() {
        _results = result;
        _highlight = 0;
        _loading = false;
      });
      
      if (_listScroll.hasClients) _listScroll.jumpTo(0);
    } catch (_) {
      if (!mounted || !_open || ticket != _revision) return;
      
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _toggle(String id) {
    final next = Set<String>.of(widget.value);
    
    if (!next.add(id)) next.remove(id);
    
    widget.onChanged(Set.unmodifiable(next));
  }

  bool get _composing => !_searchText.value.composing.isCollapsed;

  void _move(int delta) {
    if (_composing || _loading || _failed || _results.isEmpty) return;
    
    setState(() => _highlight = (_highlight + delta) % _results.length);
    
    if (!_listScroll.hasClients) return;
    
    final position = _listScroll.position;
    final top = _highlight * _rowHeight;
    final bottom = top + _rowHeight;
    
    if (top < position.pixels) {
      _listScroll.jumpTo(top);
    } else if (bottom > position.pixels + position.viewportDimension) {
      _listScroll.jumpTo(
        (bottom - position.viewportDimension)
            .clamp(0, position.maxScrollExtent)
            .toDouble(),
      );
    }
  }

  void _chooseHighlighted() {
    if (!_composing && !_loading && !_failed && _results.isNotEmpty) {
      _toggle(_results[_highlight].id);
    }
  }

  void _leave({bool backwards = false}) {
    _close(restoreFocus: true);
    // 等退出中的面板移出焦点遍历，再从触发器跳到相邻字段。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _open || !_triggerFocus.hasFocus) return;
      
      if (backwards) {
        _triggerFocus.previousFocus();
      } else {
        _triggerFocus.nextFocus();
      }
    });
  }

  Widget _buildOverlay(
    BuildContext overlayContext,
    OverlayChildLayoutInfo info,
  ) {
    // 本例根 Overlay 与窗口对齐，绕过局部 MediaQuery 已消费的 inset。
    final window = MediaQueryData.fromView(View.of(overlayContext));
    final keyboard = window.viewInsets;
    final safe = window.viewPadding;
    final visible = Rect.fromLTRB(
      safe.left + 8,
      safe.top + 8,
      info.overlaySize.width - safe.right - 8,
      info.overlaySize.height - math.max(keyboard.bottom, safe.bottom) - 8,
    );
    final anchor = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(overlayContext).scale(14) / 14,
    );
    _rowHeight = 48 * scale;
    final headerHeight = 72 * scale;
    final footerHeight = 48 * scale;
    
    if (visible.width <= 0 ||
        visible.height <= 0 ||
        !visible.overlaps(anchor)) {
      _queueLayoutClose();
      
      return const SizedBox.shrink();
    }
    
    final placement = placeMenu(
      anchor,
      visible,
      desiredHeight: 340 * scale,
      rtl: Directionality.of(overlayContext) == TextDirection.rtl,
    );
    
    // 连搜索框和一行结果也放不下时收起，避免留下无法操作的半截菜单。
    if (placement.rect.height < headerHeight + footerHeight + _rowHeight) {
      _queueLayoutClose();
      return const SizedBox.shrink();
    }
    
    return Positioned.fromRect(
      rect: placement.rect,
      child: TextFieldTapRegion(
        groupId: _tapGroup,
        onTapOutside: (_) => _close(),
        child: ExcludeFocus(
          excluding: !_open,
          child: IgnorePointer(
            ignoring: !_open,
            child: FadeTransition(
              opacity: _curve,
              child: AnimatedBuilder(
                animation: _curve,
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                    0,
                    (1 - _curve.value) * (placement.upward ? 6 : -6),
                  ),
                  child: child,
                ),
                child: Material(
                  key: const ValueKey('brand-menu'),
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                          _move(1),
                      const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                          _move(-1),
                      const SingleActivator(LogicalKeyboardKey.enter):
                          _chooseHighlighted,
                      const SingleActivator(LogicalKeyboardKey.escape): () {
                        if (!_composing) _close(restoreFocus: true);
                      },
                      const SingleActivator(LogicalKeyboardKey.tab): _leave,
                      const SingleActivator(
                        LogicalKeyboardKey.tab,
                        shift: true,
                      ): () =>
                          _leave(backwards: true),
                    },
                    child: Column(
                      children: [
                        SizedBox(
                          height: headerHeight,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              key: const ValueKey('brand-search'),
                              groupId: _tapGroup,
                              controller: _searchText,
                              focusNode: _searchFocus,
                              decoration: const InputDecoration(
                                hintText: '搜索品牌',
                                prefixIcon: Icon(Icons.search),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(child: _buildResults()),
                        const Divider(height: 1),
                        SizedBox(
                          height: footerHeight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '已选 ${widget.value.length} 项',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => widget.onChanged(const {}),
                                  child: const Text('清空'),
                                ),
                                TextButton(
                                  onPressed: () => _close(restoreFocus: true),
                                  child: const Text('完成'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    
    if (_failed) {
      return Center(
        child: TextButton.icon(
          onPressed: () => _fetch(_searchText.text, ++_revision),
          icon: const Icon(Icons.refresh),
          label: const Text('加载失败，重试'),
        ),
      );
    }
    
    if (_results.isEmpty) return const Center(child: Text('没有匹配的品牌'));
    
    final colors = Theme.of(context).colorScheme;
    
    return ListView.builder(
      controller: _listScroll,
      padding: EdgeInsets.zero,
      itemExtent: _rowHeight,
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        final checked = widget.value.contains(item.id);
        
        return CheckboxListTile(
          key: ValueKey('brand-${item.id}'),
          value: checked,
          onChanged: (_) => _toggle(item.id),
          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          tileColor: checked
              ? colors.secondaryContainer
              : index == _highlight
              ? colors.surfaceContainerHighest
              : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.catalog
        .where((b) => widget.value.contains(b.id))
        .toList();
    final summary = selected.isEmpty
        ? '请选择品牌'
        : '${selected.take(2).map((b) => b.name).join('、')}${selected.length > 2 ? ' +${selected.length - 2}' : ''}';
    
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close(restoreFocus: true);
      },
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _portal,
        overlayLocation: OverlayChildLocation.rootOverlay,
        overlayChildBuilder: _buildOverlay,
        child: TextFieldTapRegion(
          groupId: _tapGroup,
          child: Semantics(
            expanded: _open,
            child: InkWell(
              key: const ValueKey('brand-trigger'),
              focusNode: _triggerFocus,
              onTap: () => _open ? _close(restoreFocus: true) : _show(),
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '品牌',
                  errorText: widget.errorText,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(_open ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
