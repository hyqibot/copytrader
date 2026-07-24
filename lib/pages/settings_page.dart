import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.onSessionChanged,
  });

  final SettingsStore store;
  final ValueChanged<RelayApi> onSessionChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _user = TextEditingController();
  late final _pass = TextEditingController();
  late final _code = TextEditingController(text: widget.store.bindCode);
  late final _captchaAnswer = TextEditingController();
  String? _captchaId;
  String? _captchaQuestion;
  String? _msg;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (!widget.store.isLoggedIn) {
      _refreshCaptcha();
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _code.dispose();
    _captchaAnswer.dispose();
    super.dispose();
  }

  Future<void> _refreshCaptcha() async {
    try {
      final api = RelayApi(widget.store);
      final res = await api.fetchCaptcha();
      if (!mounted) return;
      setState(() {
        _captchaId = res['captcha_id']?.toString();
        _captchaQuestion = res['question']?.toString() ?? '验证码加载失败';
        _captchaAnswer.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _captchaId = null;
        _captchaQuestion = '验证码加载失败：$e';
      });
    }
  }

  Future<void> _register() async {
    final captchaId = (_captchaId ?? '').trim();
    final answer = _captchaAnswer.text.trim();
    if (captchaId.isEmpty) {
      setState(() => _msg = '请先刷新算术验证码');
      return;
    }
    if (answer.isEmpty) {
      setState(() => _msg = '请填写验证码答案');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final api = RelayApi(widget.store);
      final res = await api.register(
        _user.text.trim(),
        _pass.text,
        captchaId: captchaId,
        captchaAnswer: answer,
      );
      widget.onSessionChanged(api);
      final tip = res['tip']?.toString() ?? '';
      final gift = (res['gift_points'] as num?)?.toInt() ?? 0;
      final giftLine = gift > 0
          ? '本机首次注册，已赠送 $gift 积分。请兑换权益后绑定。'
          : '本设备已领取过注册赠送（或未识别设备），本次赠送 0 积分。可充值后兑换权益。';
      setState(() {
        _msg = '注册成功。$giftLine\n$tip';
      });
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('注册成功'),
            content: Text('$giftLine\n\n$tip'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _msg = '$e');
      await _refreshCaptcha();
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final api = RelayApi(widget.store);
      final res = await api.login(_user.text.trim(), _pass.text);
      widget.onSessionChanged(api);
      final tip = res['tip']?.toString() ?? '';
      setState(() => _msg = '登录成功。请绑定后使用跟单/日志/测试。\n$tip');
    } catch (e) {
      setState(() => _msg = '$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _bind() async {
    if (!widget.store.isLoggedIn) {
      setState(() => _msg = '请先登录或注册');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await widget.store.saveBindCode(_code.text);
      final api = RelayApi(widget.store);
      await api.bind();
      widget.onSessionChanged(api);
      setState(() => _msg = '绑定成功');
    } catch (e) {
      setState(() => _msg = '$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await widget.store.clearSession();
    widget.onSessionChanged(RelayApi(widget.store));
    setState(() => _msg = '已退出登录');
    await _refreshCaptcha();
  }

  @override
  Widget build(BuildContext context) {
    final logged = widget.store.isLoggedIn;
    final bound = widget.store.isBound;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(logged ? '已登录：${widget.store.username}' : '账号登录 / 注册',
            style: Theme.of(context).textTheme.titleMedium),
        if (!logged) ...[
          TextField(controller: _user, decoration: const InputDecoration(hintText: '用户名')),
          TextField(
            controller: _pass,
            decoration: const InputDecoration(hintText: '密码'),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _captchaQuestion == null ? '验证码加载中…' : '算一算：$_captchaQuestion',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _refreshCaptcha,
                child: const Text('换一题'),
              ),
            ],
          ),
          TextField(
            controller: _captchaAnswer,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '验证码答案'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(onPressed: _busy ? null : _login, child: const Text('登录')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _busy ? null : _register, child: const Text('注册')),
            ],
          ),
        ] else ...[
          TextButton(onPressed: _busy ? null : _logout, child: const Text('退出登录')),
        ],
        const Divider(height: 32),
        const Text('绑定码（共用，登录后绑定）'),
        TextField(
          controller: _code,
          decoration: const InputDecoration(hintText: '绑定码'),
          obscureText: true,
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : _bind,
          child: Text(_busy ? '处理中…' : '绑定交易机'),
        ),
        const SizedBox(height: 12),
        Text(
          '登录：${logged ? '是' : '否'}　绑定：${bound ? '是' : '否'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_msg != null) ...[
          const SizedBox(height: 12),
          Text(_msg!),
        ],
      ],
    );
  }
}
