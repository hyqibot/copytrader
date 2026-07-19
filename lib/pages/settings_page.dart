import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store, required this.onBound});

  final SettingsStore store;
  final ValueChanged<RelayApi> onBound;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _url = TextEditingController(text: widget.store.relayUrl);
  late final _code = TextEditingController(text: widget.store.bindCode);
  String? _msg;
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _bind() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await widget.store.saveSettings(relayUrl: _url.text, bindCode: _code.text);
      final api = RelayApi(widget.store);
      await api.bind();
      widget.onBound(api);
      setState(() => _msg = '绑定成功');
    } catch (e) {
      setState(() => _msg = '$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Relay 地址（局域网或公网，如 http://192.168.1.10:8080）'),
        TextField(controller: _url, decoration: const InputDecoration(hintText: 'http://IP:8080')),
        const SizedBox(height: 12),
        const Text('绑定码 GENDAN_BIND_CODE'),
        TextField(controller: _code, decoration: const InputDecoration(hintText: '与 PC 端相同')),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _bind,
          child: Text(_busy ? '绑定中…' : '绑定'),
        ),
        if (_msg != null) ...[
          const SizedBox(height: 12),
          Text(_msg!),
        ],
        const SizedBox(height: 24),
        Text(
          widget.store.isBound ? '已绑定 device=${widget.store.deviceId}' : '未绑定',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
