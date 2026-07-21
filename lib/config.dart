import 'package:shared_preferences/shared_preferences.dart';

/// 编译期公网地址（与电脑 `gendan_remote.env` 的 `GENDAN_PUBLIC_URL` 同名同值）。
/// 设置页不展示、不提供剪贴板改址；换域名需重编 APK。
const String kDefaultPublicUrl = String.fromEnvironment(
  'GENDAN_PUBLIC_URL',
  defaultValue: 'https://gendan.hyqibot.com',
);

class SettingsStore {
  SettingsStore._(this._prefs)
      : relayUrl = (_prefs.getString('relay_url') ?? '').trim().isNotEmpty
            ? _prefs.getString('relay_url')!.trim()
            : kDefaultPublicUrl,
        bindCode = _prefs.getString('bind_code') ?? '',
        token = _prefs.getString('token'),
        deviceId = _prefs.getString('device_id') ??
            'app-${DateTime.now().millisecondsSinceEpoch}';

  final SharedPreferences _prefs;

  /// 仅本地保存，界面不展示，避免暴露域名/IP。
  String relayUrl;
  String bindCode;
  String? token;
  String deviceId;

  static Future<SettingsStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore._(prefs);
    await prefs.setString('device_id', store.deviceId);
    return store;
  }

  bool get isBound => (token != null && token!.isNotEmpty);

  Future<void> saveBindCode(String bindCode) async {
    this.bindCode = bindCode.trim();
    await _prefs.setString('bind_code', this.bindCode);
  }

  /// 写入本地服务器地址（界面不展示；一般仅调试用）。
  Future<void> saveRelayUrl(String url) async {
    final v = url.trim().replaceFirst(RegExp(r'/+$'), '');
    if (v.isEmpty) throw StateError('地址为空');
    if (!v.startsWith('http://') && !v.startsWith('https://')) {
      throw StateError('地址须以 http:// 或 https:// 开头');
    }
    relayUrl = v;
    await _prefs.setString('relay_url', relayUrl);
  }

  Future<void> saveToken(String value) async {
    token = value;
    await _prefs.setString('token', value);
  }

  Future<void> clearToken() async {
    token = null;
    await _prefs.remove('token');
  }
}
