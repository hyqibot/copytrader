import 'package:flutter/material.dart';

import '../api.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key, required this.api});

  final RelayApi api;

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final _code = TextEditingController();
  final _amount = TextEditingController(text: '100');
  final _price = TextEditingController();
  String? _msg;
  bool _busy = false;
  dynamic _lastResult;

  @override
  void dispose() {
    _code.dispose();
    _amount.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {bool pollStatus = true}) async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await action();
      if (pollStatus) {
        await Future<void>.delayed(const Duration(seconds: 2));
        final st = await widget.api.status();
        _lastResult = st['last_query'];
      }
      setState(() => _msg = '已下发，结果见下或 PC 日志');
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
        const Text('查询'),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _busy ? null : () => _run(widget.api.balance),
              child: const Text('资金查询'),
            ),
            FilledButton(
              onPressed: _busy ? null : () => _run(widget.api.position),
              child: const Text('持仓查询'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('交易测试'),
        TextField(controller: _code, decoration: const InputDecoration(labelText: '股票代码')),
        TextField(controller: _amount, decoration: const InputDecoration(labelText: '数量'), keyboardType: TextInputType.number),
        TextField(controller: _price, decoration: const InputDecoration(labelText: '价格'), keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => widget.api.buy(
                          security: _code.text.trim(),
                          amount: int.parse(_amount.text.trim()),
                          price: double.parse(_price.text.trim()),
                        ),
                        pollStatus: false,
                      ),
              child: const Text('买入'),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => widget.api.sell(
                          security: _code.text.trim(),
                          amount: int.parse(_amount.text.trim()),
                          price: double.parse(_price.text.trim()),
                        ),
                        pollStatus: false,
                      ),
              child: const Text('卖出'),
            ),
          ],
        ),
        if (_msg != null) ...[
          const SizedBox(height: 12),
          Text(_msg!),
        ],
        if (_lastResult != null) ...[
          const SizedBox(height: 12),
          Text('最近查询: $_lastResult'),
        ],
      ],
    );
  }
}
