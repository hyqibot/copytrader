import 'package:flutter/material.dart';

import '../api.dart';
import '../tab_meta.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key, required this.api});

  final RelayApi api;

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  Map<String, dynamic> _tabs = {};
  bool _online = false;
  String? _error;
  bool _busy = false;
  String? _controlTip;
  String? _controlOwner;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final st = await widget.api.status();
      final agent = Map<String, dynamic>.from(st['agent'] as Map? ?? {});
      final control = Map<String, dynamic>.from(st['control'] as Map? ?? {});
      final owner = control['owner_username']?.toString();
      final rem = control['lease_remaining_sec'];
      setState(() {
        _tabs = Map<String, dynamic>.from(st['tabs'] as Map? ?? {});
        _online = agent['online'] == true;
        _error = null;
        _controlTip = st['tip']?.toString();
        if (owner != null && owner.isNotEmpty) {
          _controlOwner = '启停控制：$owner（剩余 $rem 秒）';
        } else {
          _controlOwner = '当前无人持有启停控制权（有权益用户点启动/停止可获取 1 小时租约）';
        }
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  /// 启动/停止指令先入队，PC Agent 轮询执行后再经心跳回写 running。
  /// 点击后约 1 秒刷新一次，再补一次以覆盖轮询延迟。
  Future<void> _refreshAfterControl() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    await _refresh();
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _start(String tabId) async {
    setState(() => _busy = true);
    try {
      await widget.api.start(tabId);
      await _refreshAfterControl();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop(String tabId) async {
    setState(() => _busy = true);
    try {
      await widget.api.stop(tabId);
      await _refreshAfterControl();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editConfig(String tabId) async {
    Map<String, dynamic> cfg = {};
    try {
      final res = await widget.api.tabConfig(tabId);
      cfg = Map<String, dynamic>.from(res['config'] as Map? ?? {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    final controllers = <String, TextEditingController>{};
    for (final group in configFieldGroups.values) {
      for (final f in group) {
        final k = f['key']!;
        controllers[k] = TextEditingController(text: '${cfg[k] ?? ''}');
      }
    }
    final sources = sourcesFor(tabId);
    int sourceIndex = int.tryParse('${cfg['sourcetype'] ?? 0}') ?? 0;
    if (!sources.any((s) => s['index'] == sourceIndex)) {
      sourceIndex = sources.first['index'] as int;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.9,
              builder: (_, scroll) {
                return ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(tabTitles[tabId] ?? tabId, style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: sourceIndex,
                      decoration: const InputDecoration(labelText: '策略来源'),
                      items: [
                        for (final s in sources)
                          DropdownMenuItem(
                            value: s['index'] as int,
                            child: Text(s['label'] as String),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setModal(() => sourceIndex = v);
                        controllers['sourcetype']!.text = '$v';
                      },
                    ),
                    for (final entry in configFieldGroups.entries) ...[
                      const SizedBox(height: 12),
                      Text(entry.key, style: Theme.of(ctx).textTheme.titleMedium),
                      for (final f in entry.value)
                        if (f['key'] != 'sourcetype')
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: TextField(
                              controller: controllers[f['key']],
                              decoration: InputDecoration(
                                labelText: f['label'],
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('保存并下发'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    if (ok == true) {
      final next = <String, dynamic>{};
      for (final entry in configFieldGroups.entries) {
        for (final f in entry.value) {
          final k = f['key']!;
          final raw = controllers[k]!.text;
          final t = f['type'];
          if (t == 'bool') {
            next[k] = raw.toLowerCase() == 'true' || raw == '1';
          } else if (t == 'int') {
            next[k] = int.tryParse(raw) ?? 0;
          } else {
            next[k] = raw;
          }
        }
      }
      next['sourcetype'] = sourceIndex;
      try {
        await widget.api.updateConfig(tabId, next);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配置已下发')));
        }
        await _refresh();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ListTile(
            title: Text(_online ? 'Agent 在线' : 'Agent 离线/未知'),
            subtitle: Text(_error ?? '下拉刷新'),
            trailing: IconButton(onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh)),
          ),
          if (_controlOwner != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_controlOwner!, style: Theme.of(context).textTheme.bodyMedium),
            ),
          if (_controlTip != null && _controlTip!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(_controlTip!, style: Theme.of(context).textTheme.bodySmall),
            ),
          for (final tid in tabOrder)
            _TabCard(
              tabId: tid,
              title: tabTitles[tid] ?? tid,
              data: Map<String, dynamic>.from(_tabs[tid] as Map? ?? {}),
              busy: _busy,
              onStart: () => _start(tid),
              onStop: () => _stop(tid),
              onEdit: () => _editConfig(tid),
            ),
        ],
      ),
    );
  }
}

class _TabCard extends StatelessWidget {
  const _TabCard({
    required this.tabId,
    required this.title,
    required this.data,
    required this.busy,
    required this.onStart,
    required this.onStop,
    required this.onEdit,
  });

  final String tabId;
  final String title;
  final Map<String, dynamic> data;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final running = data['running'] == true;
    final cfg = Map<String, dynamic>.from(data['config'] as Map? ?? {});
    final src = cfg['sourcetype'];
    final funds = cfg['zh_assets'];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(running ? '运行中' : '已停止'),
            Text('来源 index=$src  资金=$funds', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(onPressed: busy || running ? null : onStart, child: const Text('启动')),
                OutlinedButton(onPressed: busy || !running ? null : onStop, child: const Text('停止')),
                TextButton(onPressed: busy ? null : onEdit, child: const Text('全量配置')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
