/*
flutter环境准备，安装一些包：

cupertino_icons: ^1.0.8
crypto: ^3.0.7
device_info_plus: ^13.2.0
file_selector: ^1.1.0
flutter_multicast_lock: 1.1.1
path_provider: ^2.1.5
permission_handler: ^12.0.3
share_plus: ^13.3.0

-----------------------------------------------------------------

android一些配置：

android/app/src/main/AndroidManifest.xml 加入：
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
  <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
  <uses-permission android:name="android.permission.ACCESS_LOCAL_NETWORK" />

  ACCESS_LOCAL_NETWORK 只有应用面向 Android 17，也就是 target SDK 37 及以上时才需要声明和动态申请。
  运行时还要检查设备的 sdkInt，Android 16 及以下不要调用 Permission.accessLocalNetwork.request()。
  示例代码已经做了这个判断。否则旧版模拟器可能不会弹出任何权限框，只会直接返回 denied，界面上看到的就是没有局域网权限。

为了运行本文的 HTTP 示例，在 <application> 上临时增加：
<application
  其他省略...
  android:usesCleartextTraffic="true">

正式版本改成 HTTPS 后，请删除 android:usesCleartextTraffic="true"。
示例代码已经通过 flutter_multicast_lock 在发现期间持有 Android 的 WifiManager.MulticastLock，停止服务时会及时释放。
这个锁只解决 Wi-Fi 系统层过滤组播包的问题，不能穿透访客网络的 AP isolation，也不要为了省事在整个 App 生命周期里一直持有，否则会增加耗电。

-----------------------------------------------------------------

iOS 一些配置：

ios/Runner/Info.plist 中加入：
<key>NSLocalNetworkUsageDescription</key>
<string>用于发现同一局域网中的设备并直接传输文件</string>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>

示例代码使用自定义 UDP 组播，不需要声明 Bonjour 服务。
如果后续替换为 mDNS/DNS-SD，再补上真实使用的服务类型：
<key>NSBonjourServices</key>
<array>
    <string>_landrop._tcp</string>
</array>

-----------------------------------------------------------------

macOS 一些配置：
macOS 开启 App Sandbox 时，在 DebugProfile 和 Release entitlements 中确保有客户端、服务端以及用户选择文件只读权限：
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_multicast_lock/flutter_multicast_lock.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

void main() {
  runApp(const LanDropApp());
}

class LanDropApp extends StatelessWidget {
  const LanDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final LanDropEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = LanDropEngine()..addListener(_refresh);
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await _engine.start();
    } catch (error) {
      _engine.showError(error);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _engine.removeListener(_refresh);
    unawaited(_engine.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peers = _engine.peers;

    return Scaffold(
      appBar: AppBar(
        title: Text('局域网快传 · ${_engine.deviceName}'),
        actions: [
          IconButton(
            tooltip: '重新广播',
            onPressed: _engine.running ? _engine.announce : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_engine.status),
          const SizedBox(height: 12),
          if (_engine.progress != null)
            LinearProgressIndicator(value: _engine.progress),
          const SizedBox(height: 20),
          Text('附近设备', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (peers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('还没有发现设备，请确认两台设备处于同一局域网。'),
              ),
            ),
          for (final peer in peers)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.devices)),
                title: Text(peer.name),
                subtitle: Text('${peer.address.address}:${peer.port}'),
                trailing: FilledButton(
                  onPressed: _engine.busy
                      ? null
                      : () async {
                        final file = await openFile();
                        if (file == null) return;
                        try {
                          await _engine.sendFile(peer, file);
                        } catch (error) {
                          _engine.showError(error);
                        }
                      },
                  child: const Text('发送文件'),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            '内部接收目录：${_engine.receiveDirectory ?? '正在准备'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Text(
            '这是 App 私有沙盒，文件管理器不能直接访问。请从下面导出文件。',
          ),
          if (_engine.receivedFiles.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('已接收文件', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final file in _engine.receivedFiles)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(_engine.fileNameOf(file)),
                  subtitle: const Text('已安全保存在 App 内部目录'),
                  trailing: Builder(
                    builder: (buttonContext) => OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final box = buttonContext.findRenderObject()
                          as RenderBox?;
                          final origin = box == null
                              ? null
                              : box.localToGlobal(Offset.zero) & box.size;
                          await _engine.exportFile(file, origin: origin);
                        } catch (error) {
                          _engine.showError(error);
                        }
                      },
                      icon: const Icon(Icons.ios_share),
                      label: const Text('导出'),
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          const Text(
            '注意：这是学习用 HTTP 示例，请勿直接用于不可信网络或正式产品。',
          ),
        ],
      ),
    );
  }
}

class Peer {
  Peer({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.lastSeen,
  });

  final String id;
  final String name;
  final InternetAddress address;
  final int port;
  final DateTime lastSeen;
}

class ReceiveSession {
  ReceiveSession({
    required this.id,
    required this.token,
    required this.name,
    required this.size,
    required this.expectedHash,
    required this.partFile,
  });

  final String id;
  final String token;
  final String name;
  final int size;
  final String expectedHash;
  final File partFile;
}

class LanDropEngine extends ChangeNotifier {
  static const int port = 53317;
  static final InternetAddress multicastGroup =
  InternetAddress('224.0.0.167');
  static final InternetAddress limitedBroadcast =
  InternetAddress('255.255.255.255');

  final String deviceId = _randomHex(16);
  final Map<String, Peer> _peerMap = <String, Peer>{};
  final Map<String, ReceiveSession> _sessions = <String, ReceiveSession>{};
  final List<File> _receivedFiles = <File>[];
  final FlutterMulticastLock _multicastLock = FlutterMulticastLock();
  final List<NetworkInterface> _multicastInterfaces = <NetworkInterface>[];

  RawDatagramSocket? _udpSocket;
  HttpServer? _httpServer;
  StreamSubscription<RawSocketEvent>? _udpSubscription;
  StreamSubscription<HttpRequest>? _httpSubscription;
  Timer? _announceTimer;
  Timer? _cleanupTimer;
  Directory? _inbox;
  bool _multicastLockHeld = false;

  bool running = false;
  bool busy = false;
  String status = '正在启动';
  double? progress;

  String get deviceName => 'Flutter-${deviceId.substring(0, 4)}';
  String? get receiveDirectory => _inbox?.path;
  List<File> get receivedFiles => List<File>.unmodifiable(_receivedFiles);

  List<Peer> get peers {
    final result = _peerMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  Future<void> start() async {
    // ACCESS_LOCAL_NETWORK 是 Android 17 / API 37 才存在的运行时权限。
    // 旧系统不要请求，否则部分权限插件会直接返回 denied。
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 37) {
        final permission = await Permission.accessLocalNetwork.request();
        if (!permission.isGranted) {
          throw StateError('没有局域网权限，无法创建 Socket');
        }
      }

      // 声明 CHANGE_WIFI_MULTICAST_STATE 还不够，Android Wi-Fi 默认可能
      // 过滤组播包，发现期间需要真正持有 MulticastLock。
      await _multicastLock.acquireMulticastLock();
      _multicastLockHeld = true;
    }

    final documents = await getApplicationDocumentsDirectory();
    _inbox = Directory(
      '${documents.path}${Platform.pathSeparator}LanDropInbox',
    );
    await _inbox!.create(recursive: true);
    await _loadReceivedFiles();

    // TCP 与 UDP 可以监听相同端口，因为它们属于不同传输协议。
    _httpServer = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    _httpSubscription = _httpServer!.listen(_handleHttpRequest);

    _udpSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
    );
    _udpSocket!
      ..broadcastEnabled = true
      ..multicastHops = 1
      ..multicastLoopback = true;

    // 手机往往同时存在 Wi-Fi、蜂窝网络和 VPN。显式加入每个可用 IPv4
    // 网卡，避免系统默认网卡不是 Wi-Fi 时完全收不到发现报文。
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: true,
    );
    for (final interface in interfaces) {
      try {
        _udpSocket!.joinMulticast(multicastGroup, interface);
        _multicastInterfaces.add(interface);
      } catch (error) {
        // 蜂窝网络或 VPN 可能拒绝加入局域网组播，跳过即可。
        debugPrint('加入组播失败 ${interface.name}: $error');
      }
    }
    if (_multicastInterfaces.isEmpty) {
      // 桌面平台或特殊 ROM 无法枚举网卡时退回系统默认路由。
      _udpSocket!.joinMulticast(multicastGroup);
    }
    _udpSubscription = _udpSocket!.listen(_handleUdpEvent);

    running = true;
    final interfaceNames = _multicastInterfaces.isEmpty
        ? '系统默认网卡'
        : _multicastInterfaces.map((item) {
          final addresses = item.addresses
              .where((address) => address.type == InternetAddressType.IPv4)
              .map((address) => address.address)
              .join('/');
          return '${item.name}:$addresses';
        }).join(', ');
    status = '正在发现局域网设备（$interfaceNames）';
    notifyListeners();

    announce();
    _announceTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => announce(),
    );
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _removeExpiredPeers(),
    );
  }

  void announce({bool asksForReply = true}) {
    final socket = _udpSocket;
    if (socket == null) return;

    final packet = utf8.encode(jsonEncode(<String, Object>{
      'type': 'lan_drop_demo',
      'version': 1,
      'id': deviceId,
      'name': deviceName,
      'port': port,
      'announce': asksForReply,
    }));

    if (_multicastInterfaces.isEmpty) {
      socket.send(packet, multicastGroup, port);
    } else {
      // 每张成功加入组播的网卡都发送一次，接收端按设备 ID 去重。
      for (final interface in _multicastInterfaces) {
        try {
          socket.multicastInterface = interface;
          socket.send(packet, multicastGroup, port);
        } catch (error) {
          // 某张网卡可能在运行中断开，不影响其他网卡继续发送。
          debugPrint('组播发送失败 ${interface.name}: $error');
        }
      }
    }

    // 一些家用路由器会因为 IGMP Snooping 或无线隔离配置吞掉组播，
    // 同时发送受限广播作为发现兜底。接收端仍按设备 ID 去重。
    try {
      socket.send(packet, limitedBroadcast, port);
    } catch (error) {
      // 个别网络禁止广播，此时仍然保留上面的组播发现路径。
      debugPrint('广播发送失败: $error');
    }
  }

  void _handleUdpEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    Datagram? datagram;
    while ((datagram = _udpSocket?.receive()) != null) {
      try {
        final current = datagram!;
        final decoded = jsonDecode(utf8.decode(current.data));
        if (decoded is! Map<String, dynamic>) continue;
        if (decoded['type'] != 'lan_drop_demo' || decoded['version'] != 1) {
          continue;
        }

        final id = decoded['id'];
        final name = decoded['name'];
        final remotePort = decoded['port'];
        if (id is! String || name is! String || remotePort is! int) continue;
        if (id == deviceId) continue;

        _peerMap[id] = Peer(
          id: id,
          name: name,
          address: current.address,
          port: remotePort,
          lastSeen: DateTime.now(),
        );
        notifyListeners();

        // 加一点随机抖动，避免多台设备同时回复形成报文尖峰。
        if (decoded['announce'] == true) {
          final delay = 50 + Random().nextInt(250);
          Timer(Duration(milliseconds: delay), () {
            announce(asksForReply: false);
          });
        }
      } catch (_) {
        // 局域网中的未知 UDP 报文直接忽略，不能让发现服务崩溃。
      }
    }
  }

  void _removeExpiredPeers() {
    final deadline = DateTime.now().subtract(const Duration(seconds: 15));
    final before = _peerMap.length;
    _peerMap.removeWhere((_, peer) => peer.lastSeen.isBefore(deadline));
    if (_peerMap.length != before) notifyListeners();
  }

  Future<void> sendFile(Peer peer, XFile file) async {
    busy = true;
    progress = 0;
    status = '正在计算 ${file.name} 的 SHA-256';
    notifyListeners();

    try {
      final size = await file.length();
      final digest = await sha256.bind(file.openRead()).first;

      status = '正在与 ${peer.name} 协商';
      notifyListeners();

      final prepareUri = Uri(
        scheme: 'http',
        host: peer.address.address,
        port: peer.port,
        path: '/prepare',
      );
      final prepare = await _postJson(prepareUri, <String, Object>{
        'name': file.name,
        'size': size,
        'sha256': digest.toString(),
      });

      final sessionId = prepare['sessionId'] as String;
      final token = prepare['token'] as String;
      final offset = prepare['offset'] as int;
      if (offset < 0 || offset > size) {
        throw StateError('接收端返回了非法 offset：$offset');
      }

      final uploadUri = Uri(
        scheme: 'http',
        host: peer.address.address,
        port: peer.port,
        path: '/upload',
        queryParameters: <String, String>{
          'sessionId': sessionId,
          'token': token,
        },
      );

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final request = await client.postUrl(uploadUri);
        request.headers.set('x-start-offset', offset.toString());
        request.contentLength = size - offset;

        var sent = offset;
        progress = size == 0 ? 1 : sent / size;
        status = offset == 0 ? '正在发送 ${file.name}' : '从 $offset 字节继续发送';
        notifyListeners();

        // addStream 会提供背压，不会把整个文件一次塞入内存。
        final stream = file.openRead(offset).transform(
          StreamTransformer<Uint8List, List<int>>.fromHandlers(
            handleData: (chunk, sink) {
              sent += chunk.length;
              progress = size == 0 ? 1 : sent / size;
              notifyListeners();
              sink.add(chunk);
            },
          ),
        );
        await request.addStream(stream);
        final response = await request.close();
        final body = await utf8.decoder.bind(response).join();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('上传失败 ${response.statusCode}: $body');
        }
      } finally {
        client.close(force: true);
      }

      progress = 1;
      status = '${file.name} 已发送给 ${peer.name}';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, Object> data,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(data));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('协商失败 ${response.statusCode}: $body');
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/health') {
        await _jsonResponse(request.response, HttpStatus.ok, <String, Object>{
          'name': deviceName,
          'deviceId': deviceId,
          'port': port,
        });
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/prepare') {
        await _handlePrepare(request);
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/upload') {
        await _handleUpload(request);
        return;
      }
      await _jsonResponse(
        request.response,
        HttpStatus.notFound,
        <String, Object>{'error': 'not_found'},
      );
    } catch (error) {
      // 如果客户端已断开，写响应可能再次失败，所以这里兜底吞掉异常。
      try {
        await _jsonResponse(
          request.response,
          HttpStatus.internalServerError,
          <String, Object>{'error': error.toString()},
        );
      } catch (_) {}
    }
  }

  Future<void> _handlePrepare(HttpRequest request) async {
    final text = await _readLimitedBody(request, 64 * 1024);
    final body = jsonDecode(text);
    if (body is! Map<String, dynamic>) {
      await _badRequest(request.response, '请求体不是 JSON 对象');
      return;
    }

    final rawName = body['name'];
    final size = body['size'];
    final expectedHash = body['sha256'];

    if (rawName is! String ||
        size is! int ||
        expectedHash is! String ||
        size < 0 ||
        size > 20 * 1024 * 1024 * 1024 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash)
    ) {
      await _badRequest(request.response, '文件元数据不合法');
      return;
    }

    final name = _safeFileName(rawName);
    final partFile = File(
      '${_inbox!.path}${Platform.pathSeparator}.$expectedHash.part',
    );
    var offset = await partFile.exists() ? await partFile.length() : 0;
    if (offset > size) {
      await partFile.delete();
      offset = 0;
    }

    final session = ReceiveSession(
      id: _randomHex(16),
      token: _randomHex(32),
      name: name,
      size: size,
      expectedHash: expectedHash,
      partFile: partFile,
    );
    _sessions[session.id] = session;

    await _jsonResponse(request.response, HttpStatus.ok, <String, Object>{
      'sessionId': session.id,
      'token': session.token,
      'offset': offset,
    });
  }

  Future<void> _handleUpload(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['sessionId'];
    final token = request.uri.queryParameters['token'];
    final startOffset = int.tryParse(
      request.headers.value('x-start-offset') ?? '',
    );
    final session = _sessions[sessionId];

    if (session == null || token != session.token || startOffset == null) {
      await _jsonResponse(
        request.response,
        HttpStatus.forbidden,
        <String, Object>{'error': 'invalid_session'},
      );
      return;
    }

    final actualOffset = await session.partFile.exists()
        ? await session.partFile.length()
        : 0;
    if (startOffset != actualOffset) {
      await _jsonResponse(
        request.response,
        HttpStatus.conflict,
        <String, Object>{'error': 'offset_mismatch', 'offset': actualOffset},
      );
      return;
    }

    final sink = session.partFile.openWrite(mode: FileMode.append);
    var written = actualOffset;
    try {
      await for (final chunk in request) {
        if (written + chunk.length > session.size) {
          throw const FormatException('接收内容超过声明大小');
        }
        sink.add(chunk);
        written += chunk.length;
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (written != session.size) {
      await _jsonResponse(request.response, HttpStatus.ok, <String, Object>{
        'complete': false,
        'offset': written,
      });
      return;
    }

    status = '正在校验 ${session.name}';
    notifyListeners();
    final digest = await sha256.bind(session.partFile.openRead()).first;
    if (digest.toString() != session.expectedHash) {
      await session.partFile.delete();
      _sessions.remove(session.id);
      await _jsonResponse(
        request.response,
        422,
        <String, Object>{'error': 'sha256_mismatch'},
      );
      return;
    }

    final target = await _availableTarget(session.name);
    await session.partFile.rename(target.path);
    _sessions.remove(session.id);
    _receivedFiles.insert(0, target);
    status = '已接收 ${session.name}';
    notifyListeners();

    await _jsonResponse(request.response, HttpStatus.ok, <String, Object>{
      'complete': true,
      'name': session.name,
    });
  }

  Future<File> _availableTarget(String name) async {
    var candidate = File(
      '${_inbox!.path}${Platform.pathSeparator}$name',
    );
    if (!await candidate.exists()) return candidate;

    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final extension = dot > 0 ? name.substring(dot) : '';
    var index = 1;
    while (await candidate.exists()) {
      candidate = File(
        '${_inbox!.path}${Platform.pathSeparator}$stem ($index)$extension',
      );
      index++;
    }
    return candidate;
  }

  Future<void> _loadReceivedFiles() async {
    final inbox = _inbox;
    if (inbox == null) return;

    final files = await inbox
        .list()
        .where((entity) {
          if (entity is! File) return false;
          return !fileNameOf(entity).startsWith('.');
        })
        .cast<File>()
        .toList();
    files.sort((a, b) {
      return b.lastModifiedSync().compareTo(a.lastModifiedSync());
    });
    _receivedFiles
      ..clear()
      ..addAll(files);
  }

  String fileNameOf(File file) {
    return Uri.decodeComponent(file.uri.pathSegments.last);
  }

  Future<void> exportFile(File file, {Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        title: '导出 ${fileNameOf(file)}',
        sharePositionOrigin: origin,
      ),
    );
  }

  Future<String> _readLimitedBody(
    Stream<List<int>> stream,
    int maxBytes,
  ) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('请求体过大');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }

  Future<void> _badRequest(HttpResponse response, String message) {
    return _jsonResponse(
      response,
      HttpStatus.badRequest,
      <String, Object>{'error': message},
    );
  }

  Future<void> _jsonResponse(
    HttpResponse response,
    int statusCode,
    Map<String, Object> body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  void showError(Object error) {
    busy = false;
    progress = null;
    status = '出错了：$error';
    notifyListeners();
  }

  Future<void> close() async {
    running = false;
    _announceTimer?.cancel();
    _cleanupTimer?.cancel();
    await _udpSubscription?.cancel();
    await _httpSubscription?.cancel();
    _udpSocket?.close();
    await _httpServer?.close(force: true);
    if (Platform.isAndroid && _multicastLockHeld) {
      await _multicastLock.releaseMulticastLock();
      _multicastLockHeld = false;
    }
    super.dispose();
  }

  static String _safeFileName(String raw) {
    final leaf = raw.replaceAll('\\', '/').split('/').last;
    final cleaned = leaf
        .replaceAll(RegExp(r'[\x00-\x1f<>:"|?*]'), '_')
        .trim();
    return cleaned.isEmpty ? 'unnamed_file' : cleaned;
  }

  static String _randomHex(int byteLength) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}
