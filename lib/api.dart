import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';

class RelayApi {
  RelayApi(this.store, {http.Client? client}) : _client = client ?? http.Client();

  final SettingsStore store;
  final http.Client _client;

  /// EdgeOne 空闲上限 300s；默认 25s ping，远低于阈值。
  static const Duration wsPingInterval = Duration(seconds: 25);
  static const Duration wsReconnectBase = Duration(seconds: 2);
  static const int wsReconnectMaxMultiplier = 8;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = store.relayUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.isEmpty) throw StateError('请先设置 Relay 地址');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (store.token != null) 'Authorization': 'Bearer ${store.token}',
      };

  Future<Map<String, dynamic>> bind() async {
    final response = await _client.post(
      _uri('/v1/auth/bind'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': 'app',
        'bind_code': store.bindCode,
        'device_id': store.deviceId,
      }),
    );
    final body = _decode(response);
    final token = body['token'] as String?;
    if (token == null || token.isEmpty) throw StateError('未返回 token');
    await store.saveToken(token);
    return body;
  }

  Future<Map<String, dynamic>> status() => _get('/v1/status');

  Future<Map<String, dynamic>> tabConfig(String tabId) =>
      _get('/v1/tabs/$tabId/config');

  Future<void> start(String tabId) => _post('/v1/tabs/$tabId/start');
  Future<void> stop(String tabId) => _post('/v1/tabs/$tabId/stop');

  Future<void> updateConfig(String tabId, Map<String, dynamic> config) async {
    final response = await _client.put(
      _uri('/v1/tabs/$tabId/config'),
      headers: _headers,
      body: jsonEncode({'config': config}),
    );
    _decode(response);
  }

  Future<void> balance() => _post('/v1/test/balance');
  Future<void> position() => _post('/v1/test/position');

  Future<void> buy({
    required String security,
    required int amount,
    required double price,
  }) =>
      _post('/v1/test/buy', {
        'security': security,
        'amount': amount,
        'price': price,
      });

  Future<void> sell({
    required String security,
    required int amount,
    required double price,
  }) =>
      _post('/v1/test/sell', {
        'security': security,
        'amount': amount,
        'price': price,
      });

  Future<List<dynamic>> logs({int limit = 500}) async =>
      (await _get('/v1/logs', {'limit': '$limit'}))['logs'] as List<dynamic>? ?? [];

  /// 长连接事件流：定时 `ping` 保活 + 断线指数退避自动重连。
  /// 取消订阅后停止重连。
  Stream<Map<String, dynamic>> events({
    Duration pingInterval = wsPingInterval,
    Duration reconnectBase = wsReconnectBase,
  }) {
    late StreamController<Map<String, dynamic>> controller;
    var stopped = false;
    var attempt = 0;
    WebSocketChannel? channel;
    Timer? pingTimer;
    StreamSubscription<dynamic>? sub;

    Future<void> cleanupChannel() async {
      pingTimer?.cancel();
      pingTimer = null;
      await sub?.cancel();
      sub = null;
      try {
        await channel?.sink.close();
      } catch (_) {}
      channel = null;
    }

    Future<void> connectLoop() async {
      while (!stopped && !controller.isClosed) {
        final token = store.token;
        if (token == null || token.isEmpty) {
          await Future<void>.delayed(reconnectBase);
          continue;
        }
        try {
          final base = _uri('/v1/ws');
          final socketUri = base.replace(
            scheme: base.scheme == 'https' ? 'wss' : 'ws',
            queryParameters: {'token': token},
          );
          channel = WebSocketChannel.connect(socketUri);
          final ready = channel!.ready;
          await ready.timeout(const Duration(seconds: 15));

          pingTimer = Timer.periodic(pingInterval, (_) {
            try {
              channel?.sink.add('ping');
            } catch (_) {}
          });

          final done = Completer<void>();
          sub = channel!.stream.listen(
            (event) {
              attempt = 0;
              try {
                final decoded = jsonDecode(event as String);
                if (decoded is! Map<String, dynamic>) return;
                if (decoded['type'] == 'pong') return;
                if (!controller.isClosed) controller.add(decoded);
              } catch (e, st) {
                if (!controller.isClosed) controller.addError(e, st);
              }
            },
            onError: (Object e, StackTrace st) {
              if (!done.isCompleted) done.completeError(e, st);
            },
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
            cancelOnError: true,
          );

          await done.future;
        } catch (_) {
          // 连接失败或中断后进入重连
        } finally {
          await cleanupChannel();
        }

        if (stopped || controller.isClosed) break;
        attempt += 1;
        final factor = math.min(attempt, wsReconnectMaxMultiplier);
        await Future<void>.delayed(reconnectBase * factor);
      }
    }

    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        unawaited(connectLoop());
      },
      onCancel: () async {
        stopped = true;
        await cleanupChannel();
      },
    );

    return controller.stream;
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    final response = await _client.get(_uri(path, query), headers: _headers);
    return _decode(response);
  }

  Future<void> _post(String path, [Map<String, dynamic>? body]) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final text = response.body;
    Map<String, dynamic> body;
    try {
      body = jsonDecode(text.isEmpty ? '{}' : text) as Map<String, dynamic>;
    } catch (_) {
      throw StateError('HTTP ${response.statusCode}: $text');
    }
    if (response.statusCode >= 400) {
      throw StateError('HTTP ${response.statusCode}: ${body['detail'] ?? text}');
    }
    return body;
  }
}
