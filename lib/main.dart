import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'config.dart';
import 'notifications.dart';
import 'pages/account_page.dart';
import 'pages/control_page.dart';
import 'pages/huanyin_chaoi_page.dart';
import 'pages/logs_page.dart';
import 'pages/longhu_ai_page.dart';
import 'pages/settings_page.dart';
import 'pages/test_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TradeNotifications.init();
  final store = await SettingsStore.load();
  runApp(GendanApp(store: store));
}

class GendanApp extends StatelessWidget {
  const GendanApp({super.key, required this.store});

  final SettingsStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '跟单神控',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0B6E4F), useMaterial3: true),
      home: GendanHome(store: store),
    );
  }
}

class GendanHome extends StatefulWidget {
  const GendanHome({super.key, required this.store});

  final SettingsStore store;

  @override
  State<GendanHome> createState() => _GendanHomeState();
}

class _GendanHomeState extends State<GendanHome> {
  late RelayApi _api = RelayApi(widget.store);
  StreamSubscription<Map<String, dynamic>>? _events;
  final _eventBus = StreamController<Map<String, dynamic>>.broadcast();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _connectEvents();
  }

  void _connectEvents() {
    if (!widget.store.isBound) {
      _events?.cancel();
      _events = null;
      return;
    }
    _events?.cancel();
    _events = _api.events().listen(
      (event) {
        if (!_eventBus.isClosed) _eventBus.add(event);
        if (event['type'] == 'alert') {
          final data = Map<String, dynamic>.from(event['data'] as Map? ?? {});
          final title = data['title']?.toString() ?? '跟单通知';
          final body = data['body']?.toString() ?? '';
          unawaited(TradeNotifications.showTradeAlert(title: title, body: body));
          if (mounted && body.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title：$body'), duration: const Duration(seconds: 4)),
            );
          }
        }
      },
      onError: (_) {},
    );
  }

  void _onSessionChanged(RelayApi api) {
    setState(() => _api = api);
    _connectEvents();
  }

  @override
  void dispose() {
    _events?.cancel();
    unawaited(_eventBus.close());
    super.dispose();
  }

  Widget _needLogin() => const Center(child: Text('请先在「设置」注册/登录'));
  Widget _needBind() => const Center(child: Text('请先登录并在「设置」绑定交易机'));

  @override
  Widget build(BuildContext context) {
    final logged = widget.store.isLoggedIn;
    final bound = widget.store.isBound;
    final pages = <Widget>[
      if (bound) ControlPage(api: _api) else (logged ? _needBind() : _needLogin()),
      if (bound) TestPage(api: _api) else (logged ? _needBind() : _needLogin()),
      if (bound)
        LogsPage(api: _api, events: _eventBus.stream)
      else
        (logged ? _needBind() : _needLogin()),
      if (logged) const HuanyinChaoiPage() else _needLogin(),
      const LonghuAiPage(),
      if (logged) AccountPage(api: _api, store: widget.store) else _needLogin(),
      SettingsPage(store: widget.store, onSessionChanged: _onSessionChanged),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('跟单神控')),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.play_circle), label: '跟单'),
          NavigationDestination(icon: Icon(Icons.science), label: '测试'),
          NavigationDestination(icon: Icon(Icons.article), label: '日志'),
          NavigationDestination(icon: Icon(Icons.smart_toy), label: '幻银超i'),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: '龙虎ai'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
