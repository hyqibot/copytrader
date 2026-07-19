import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';

class RelayApi {
  RelayApi(this.store, {http.Client? client}) : _client = client ?? http.Client();

  final SettingsStore store;
  final http.Client _client;

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

  Future<List<dynamic>> logs({int limit = 200}) async =>
      (await _get('/v1/logs', {'limit': '$limit'}))['logs'] as List<dynamic>? ?? [];

  Stream<Map<String, dynamic>> events() async* {
    final base = _uri('/v1/ws');
    final socketUri = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      queryParameters: {'token': store.token ?? ''},
    );
    final channel = WebSocketChannel.connect(socketUri);
    try {
      await for (final event in channel.stream) {
        final decoded = jsonDecode(event as String);
        if (decoded is Map<String, dynamic>) yield decoded;
      }
    } finally {
      await channel.sink.close();
    }
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
