import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({
    super.key,
    required this.api,
    required this.events,
  });

  final RelayApi api;
  final Stream<Map<String, dynamic>> events;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  static const _maxLines = 3000;

  final _scroll = ScrollController();
  final List<String> _logs = [];
  StreamSubscription<Map<String, dynamic>>? _sub;
  String? _error;
  var _loading = true;
  var _stickToBottom = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _sub = widget.events.listen(_onEvent, onError: (_) {});
    _load();
  }

  @override
  void didUpdateWidget(covariant LogsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _sub?.cancel();
      _sub = widget.events.listen(_onEvent, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    // 距底部 80px 内视为跟随最新
    _stickToBottom = pos.maxScrollExtent - pos.pixels < 80;
  }

  void _onEvent(Map<String, dynamic> event) {
    if (event['type'] != 'log') return;
    final data = event['data'];
    if (data is! Map) return;
    final line = data['line']?.toString();
    if (line == null || line.isEmpty) return;
    setState(() {
      _logs.add(line);
      if (_logs.length > _maxLines) {
        _logs.removeRange(0, _logs.length - _maxLines);
      }
    });
    _scheduleScrollToEnd();
  }

  void _scheduleScrollToEnd() {
    if (!_stickToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final logs = await widget.api.logs(limit: 500);
      if (!mounted) return;
      setState(() {
        _logs
          ..clear()
          ..addAll(logs.map((e) => '$e'));
        _error = null;
        _loading = false;
        _stickToBottom = true;
      });
      _scheduleScrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_error != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              dense: true,
              title: Text(_error!, style: const TextStyle(fontSize: 12)),
              trailing: TextButton(onPressed: _load, child: const Text('重试')),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading && _logs.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: CircularProgressIndicator()),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: _logs.isEmpty ? 1 : _logs.length,
                    itemBuilder: (context, i) {
                      if (_logs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: Text('暂无日志（运行后将自动滚动显示）'),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: SelectableText(
                          _logs[i],
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.35),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
