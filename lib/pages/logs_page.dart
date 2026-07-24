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
  Timer? _delayedRefresh;
  String? _error;
  var _loading = true;
  var _stickToBottom = true;
  var _refreshing = false;
  var _pendingRefresh = false;

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
    _delayedRefresh?.cancel();
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
    // 推送到达后立刻 HTTP 刷新一次，1 秒后再刷一次，确保列表跟上服务端
    _scheduleRefreshAfterPush();
  }

  void _scheduleRefreshAfterPush() {
    unawaited(_load(quiet: true));
    _delayedRefresh?.cancel();
    _delayedRefresh = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      unawaited(_load(quiet: true));
    });
  }

  void _scheduleScrollToEnd() {
    if (!_stickToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _load({bool quiet = false}) async {
    if (_refreshing) {
      _pendingRefresh = true;
      return;
    }
    _refreshing = true;
    if (!quiet || _logs.isEmpty) {
      setState(() => _loading = true);
    }
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
    } finally {
      _refreshing = false;
      if (_pendingRefresh && mounted) {
        _pendingRefresh = false;
        unawaited(_load(quiet: true));
      }
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
              trailing: TextButton(onPressed: () => _load(), child: const Text('重试')),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(),
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
