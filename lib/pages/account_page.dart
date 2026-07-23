import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../config.dart';

/// 我的：积分、兑换、卡密充值、收款说明、控制权提示。
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.api, required this.store});

  final RelayApi api;
  final SettingsStore store;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _recharge;
  String? _error;
  bool _busy = false;
  final _card = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _card.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = await widget.api.me();
      final info = await widget.api.rechargeInfo();
      if (!mounted) return;
      setState(() {
        _me = me;
        _recharge = info;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _redeem(String plan) async {
    setState(() => _busy = true);
    try {
      await widget.api.redeem(plan);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('兑换成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeemCard() async {
    setState(() => _busy = true);
    try {
      await widget.api.redeemCard(_card.text);
      _card.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('卡密充值成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmtExp(dynamic v) {
    if (v == null) return '未开通';
    final sec = (v is num) ? v.toDouble() : double.tryParse('$v');
    if (sec == null) return '$v';
    final dt = DateTime.fromMillisecondsSinceEpoch((sec * 1000).round());
    return dt.toLocal().toString().substring(0, 19);
  }

  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(_me?['user'] as Map? ?? {});
    final control = Map<String, dynamic>.from(_me?['control'] as Map? ?? {});
    final tip = _me?['tip']?.toString() ?? '';
    final plans = Map<String, dynamic>.from(_me?['plans'] as Map? ?? {});
    final remark = _recharge?['remark_format']?.toString() ?? '充值+用户名';
    final wechat = _recharge?['wechat']?.toString() ?? '';
    final hint = _recharge?['hint']?.toString() ?? '';
    final uname = widget.store.username ?? user['username']?.toString() ?? '';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          Text('账号：$uname', style: Theme.of(context).textTheme.titleMedium),
          Text('积分：${user['points'] ?? '-'}'),
          Text('启停权益到期：${_fmtExp(user['control_expires_at'])}'),
          Text('权益有效：${user['control_active'] == true ? '是' : '否'}'),
          const SizedBox(height: 8),
          if (control.isNotEmpty) ...[
            Text(
              '当前启停控制：${control['owner_username'] ?? '无人'}'
              '${control['lease_remaining_sec'] != null && control['owner_username'] != null ? '（剩余 ${control['lease_remaining_sec']} 秒）' : ''}',
            ),
          ],
          if (tip.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(tip, style: Theme.of(context).textTheme.bodySmall),
          ],
          const Divider(height: 32),
          Text('兑换启停权益', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in plans.entries)
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _redeem(e.key),
                  child: Text(
                    '${(e.value as Map)['label'] ?? e.key}（${(e.value as Map)['points']}分）',
                  ),
                ),
              if (plans.isEmpty) ...[
                FilledButton(onPressed: _busy ? null : () => _redeem('1m'), child: const Text('1个月（1000分）')),
                FilledButton(onPressed: _busy ? null : () => _redeem('1q'), child: const Text('1季（2000分）')),
                FilledButton(onPressed: _busy ? null : () => _redeem('1y'), child: const Text('1年（6000分）')),
              ],
            ],
          ),
          const Divider(height: 32),
          Text('充值（半自动）', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('1. 按下方信息转账，备注：$remark（例：充值+$uname）'),
          if (wechat.isNotEmpty) Text('微信号/收款：$wechat'),
          if ((_recharge?['qr_url']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('收款码：', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Center(
              child: Image.network(
                _recharge!['qr_url'].toString(),
                height: 180,
                width: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text('收款码加载失败'),
              ),
            ),
          ],
          if (hint.isNotEmpty) Text(hint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text('2. 到账后客服发卡密，在此兑换：'),
          TextField(
            controller: _card,
            decoration: const InputDecoration(hintText: '卡密'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy ? null : _redeemCard, child: const Text('卡密充值')),
          TextButton(
            onPressed: () {
              final text = '充值+$uname';
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已复制备注：$text')));
            },
            child: const Text('复制转账备注'),
          ),
        ],
      ),
    );
  }
}
