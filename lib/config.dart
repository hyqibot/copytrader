import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  SettingsStore._(this._prefs, {String? defaultRelayUrl})
      : relayUrl = _prefs.getString('relay_url') ?? defaultRelayUrl ?? '',
        bindCode = _prefs.getString('bind_code') ?? '',
        token = _prefs.getString('token'),
        deviceId = _prefs.getString('device_id') ??
            'app-${DateTime.now().millisecondsSinceEpoch}';

  final SharedPreferences _prefs;
  String relayUrl;
  String bindCode;
  String? token;
  String deviceId;

  static Future<SettingsStore> load({String? defaultRelayUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore._(prefs, defaultRelayUrl: defaultRelayUrl);
    await prefs.setString('device_id', store.deviceId);
    return store;
  }

  bool get isBound => (token != null && token!.isNotEmpty);

  Future<void> saveSettings({required String relayUrl, required String bindCode}) async {
    this.relayUrl = relayUrl.trim();
    this.bindCode = bindCode.trim();
    await _prefs.setString('relay_url', this.relayUrl);
    await _prefs.setString('bind_code', this.bindCode);
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
