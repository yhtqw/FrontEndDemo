import 'package:flutter/foundation.dart';

class Product {
  const Product(this.code, this.name, this.unit);
  final String code;
  final String name;
  final String unit;

  // 查询返回新对象时，同一商品仍按条码合并。
  @override
  bool operator ==(Object other) => other is Product && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

const catalog = <Product>[
  Product('SKU-0001', '冷萃咖啡', '瓶'),
  Product('SKU-0002', '燕麦饼干', '盒'),
];

Future<Product?> lookupProduct(String code) async {
  // 模拟商品查询；替换此处即可连接自己的商品库。
  await Future<void>.delayed(const Duration(milliseconds: 450));
  for (final product in catalog) {
    if (product.code == code) return product;
  }
  return null;
}

class InventoryStore extends ChangeNotifier {
  final Map<Product, int> _items = {};
  Map<Product, int> get items => Map.unmodifiable(_items);
  int get total => _items.values.fold(0, (sum, count) => sum + count);

  void add(Product product) {
    _items.update(product, (count) => count + 1, ifAbsent: () => 1);
    notifyListeners();
  }
}

enum IntakeFeedback { ready, success, failure }

class ScanIntake extends ChangeNotifier {
  ScanIntake(this.store, {this.lookup = lookupProduct});
  final InventoryStore store;
  final Future<Product?> Function(String) lookup;
  bool _active = false;
  bool _closed = false;
  int _epoch = 0;
  bool busy = false;
  String? lastAccepted;
  String message = '将商品条码放入框内';
  IntakeFeedback feedback = IntakeFeedback.ready;

  void setActive(bool active) {
    if (_closed || _active == active) return;
    _active = active;
    _epoch++;
    if (busy) {
      feedback = IntakeFeedback.ready;
      message = '将商品条码放入框内';
    }
    busy = false;
    notifyListeners();
  }

  void rearm() {
    if (_closed || !_active || busy) return;
    lastAccepted = null;
    feedback = IntakeFeedback.ready;
    message = '可以再次扫描同一商品';
    notifyListeners();
  }

  Future<bool> accept(String code) async {
    if (_closed || !_active || busy || code == lastAccepted) return false;
    if (code.isEmpty || code.length > 128) return false;
    busy = true; // 在第一个 await 之前锁住入口。
    feedback = IntakeFeedback.ready;
    message = '正在匹配商品…';
    final ticket = _epoch;
    notifyListeners();

    try {
      final product = await lookup(code);
      if (_closed || !_active || ticket != _epoch) return false;
      if (product == null) {
        feedback = IntakeFeedback.failure;
        message = '未找到商品，请确认条码';
        return false;
      }
      store.add(product);
      lastAccepted = code;
      feedback = IntakeFeedback.success;
      message = '${product.name} 已加入清单';
      return true;
    } catch (_) {
      if (!_closed && ticket == _epoch) {
        feedback = IntakeFeedback.failure;
        message = '商品查询失败，请重试';
      }
      return false;
    } finally {
      if (!_closed && ticket == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    _epoch++;
    super.dispose();
  }
}
