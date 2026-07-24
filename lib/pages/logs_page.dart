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
  final _commentInput = TextEditingController();
  final _commentScroll = ScrollController();
  final List<String> _logs = [];
  final List<Map<String, dynamic>> _comments = [];
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _delayedRefresh;
  String? _error;
  String? _commentError;
  String? _replyToId;
  String? _replyToName;
  var _loading = true;
  var _stickToBottom = true;
  var _refreshing = false;
  var _pendingRefresh = false;
  var _commentBusy = false;
  var _commentsExpanded = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _sub = widget.events.listen(_onEvent, onError: (_) {});
    _load();
    unawaited(_loadComments());
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
    _commentScroll.dispose();
    _commentInput.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    _stickToBottom = pos.maxScrollExtent - pos.pixels < 80;
  }

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    if (type == 'log') {
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
      _scheduleRefreshAfterPush();
      return;
    }
    if (type == 'comment') {
      unawaited(_loadComments());
    }
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

  void _scrollCommentsToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_commentScroll.hasClients) return;
      _commentScroll.jumpTo(_commentScroll.position.maxScrollExtent);
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

  Future<void> _loadComments() async {
    try {
      final items = await widget.api.comments(limit: 200);
      if (!mounted) return;
      setState(() {
        _comments
          ..clear()
          ..addAll(items);
        _commentError = null;
      });
      _scrollCommentsToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() => _commentError = '$e');
    }
  }

  Future<void> _sendComment() async {
    final text = _commentInput.text.trim();
    if (text.isEmpty || _commentBusy) return;
    setState(() => _commentBusy = true);
    try {
      await widget.api.createComment(text, parentId: _replyToId);
      _commentInput.clear();
      setState(() {
        _replyToId = null;
        _replyToName = null;
      });
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _commentBusy = false);
    }
  }

  Future<void> _deleteComment(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除评论'),
        content: const Text('确定删除这条评论？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.deleteComment(id);
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String _fmtTime(dynamic ts) {
    final v = ts is num ? ts.toDouble() : double.tryParse('$ts');
    if (v == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch((v * 1000).round());
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  List<Map<String, dynamic>> get _roots =>
      _comments.where((c) => c['parent_id'] == null).toList();

  List<Map<String, dynamic>> _repliesOf(String id) =>
      _comments.where((c) => c['parent_id']?.toString() == id).toList();

  Widget _commentTile(Map<String, dynamic> c, {bool isReply = false}) {
    final me = widget.api.store.username;
    final uname = c['username']?.toString() ?? '';
    final isMine = me != null && me == uname;
    return Padding(
      padding: EdgeInsets.only(left: isReply ? 16 : 0, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$uname · ${_fmtTime(c['created_at'])}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _replyToId = c['id']?.toString();
                    _replyToName = uname;
                    _commentsExpanded = true;
                  });
                },
                child: const Text('回复'),
              ),
              if (isMine)
                TextButton(
                  onPressed: () => _deleteComment('${c['id']}'),
                  child: const Text('删除'),
                ),
            ],
          ),
          Text(c['content']?.toString() ?? ''),
        ],
      ),
    );
  }

  Widget _buildCommentsPanel() {
    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            dense: true,
            title: Text('评论（${_comments.length}）'),
            subtitle: const Text('同机绑定用户共享 · 实时同步'),
            trailing: IconButton(
              icon: Icon(_commentsExpanded ? Icons.expand_more : Icons.expand_less),
              onPressed: () => setState(() => _commentsExpanded = !_commentsExpanded),
            ),
          ),
          if (_commentsExpanded) ...[
            if (_commentError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_commentError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            SizedBox(
              height: 160,
              child: _comments.isEmpty
                  ? const Center(child: Text('暂无评论，来说两句'))
                  : ListView(
                      controller: _commentScroll,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      children: [
                        for (final root in _roots) ...[
                          _commentTile(root),
                          for (final r in _repliesOf('${root['id']}'))
                            _commentTile(r, isReply: true),
                        ],
                      ],
                    ),
            ),
            if (_replyToId != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(child: Text('回复 @$_replyToName', style: Theme.of(context).textTheme.bodySmall)),
                    TextButton(
                      onPressed: () => setState(() {
                        _replyToId = null;
                        _replyToName = null;
                      }),
                      child: const Text('取消'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentInput,
                      decoration: const InputDecoration(
                        hintText: '写评论…',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _commentBusy ? null : _sendComment,
                    child: const Text('发送'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
            onRefresh: () async {
              await _load();
              await _loadComments();
            },
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
        _buildCommentsPanel(),
      ],
    );
  }
}
