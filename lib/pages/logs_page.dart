import 'package:flutter/material.dart';

import '../api.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key, required this.api});

  final RelayApi api;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  List<dynamic> _logs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final logs = await widget.api.logs();
      setState(() {
        _logs = logs;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_logs.isEmpty) const Text('暂无日志（下拉刷新）'),
          for (final line in _logs.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('$line', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ),
        ],
      ),
    );
  }
}
