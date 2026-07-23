import 'package:shared_preferences/shared_preferences.dart';

/// 编译期公网地址（与电脑 `gendan_remote.env` 的 `GENDAN_PUBLIC_URL` 同名同值）。
const String kDefaultPublicUrl = String.fromEnvironment(
  'GENDAN_PUBLIC_URL',
  defaultValue: '[REDACTED]',
);

class SettingsStore {
  SettingsStore._(this._prefs)
      : relayUrl = (_prefs.getString('relay_url') ?? '').trim().isNotEmpty
            ? _prefs.getString('relay_url')!.trim()
            : kDefaultPublicUrl,
        bindCode = _prefs.getString('bind_code') ?? '',
        token = _prefs.getString('token'),
        username = _prefs.getString('username'),
        deviceId = _prefs.getString('device_id') ??
            'app-${DateTime.now().millisecondsSinceEpoch}';

  final SharedPreferences _prefs;

  String relayUrl;
  String bindCode;
  String? token;
  String? username;
  String deviceId;

  static Future<SettingsStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore._(prefs);
    await prefs.setString('device_id', store.deviceId);
    return store;
  }

  bool get isLoggedIn => token != null && token!.isNotEmpty && (username?.isNotEmpty ?? false);

  /// 已登录且已绑定交易机（JWT 含 tenant）。
  bool get isBound => isLoggedIn && (_prefs.getBool('bound') ?? false);

  Future<void> saveBindCode(String bindCode) async {
    this.bindCode = bindCode.trim();
    await _prefs.setString('bind_code', this.bindCode);
  }

  Future<void> saveRelayUrl(String url) async {
    final v = url.trim().replaceFirst(RegExp(r'/+$'), '');
    if (v.isEmpty) throw StateError('地址为空');
    if (!v.startsWith('http://') && !v.startsWith('https://')) {
      throw StateError('地址须以 http:// 或 https:// 开头');
    }
    relayUrl = v;
    await _prefs.setString('relay_url', relayUrl);
  }

  Future<void> saveSession({
    required String token,
    required String username,
    required bool bound,
    String? deviceId,
  }) async {
    this.token = token;
    this.username = username;
    await _prefs.setString('token', token);
    await _prefs.setString('username', username);
    await _prefs.setBool('bound', bound);
    if (deviceId != null && deviceId.isNotEmpty) {
      this.deviceId = deviceId;
      await _prefs.setString('device_id', deviceId);
    }
  }

  Future<void> setBound(bool value) async {
    await _prefs.setBool('bound', value);
  }

  Future<void> clearSession() async {
    token = null;
    username = null;
    await _prefs.remove('token');
    await _prefs.remove('username');
    await _prefs.setBool('bound', false);
  }
}
