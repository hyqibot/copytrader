import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'config.dart';
import 'pages/control_page.dart';
import 'pages/logs_page.dart';
import 'pages/longhu_ai_page.dart';
import 'pages/settings_page.dart';
import 'pages/test_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _connectEvents();
  }

  void _connectEvents() {
    if (!widget.store.isBound) return;
    _events?.cancel();
    // events() 内部已做 25s ping + 断线自动重连；此处只消费业务事件
    _events = _api.events().listen(
      (event) {
        if (event['type'] == 'alert' && mounted) {
          final data = Map<String, dynamic>.from(event['data'] as Map);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${data['title']}: ${data['body']}')),
          );
        }
      },
      onError: (_) {},
    );
  }

  void _setApi(RelayApi api) {
    setState(() => _api = api);
    _connectEvents();
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bound = widget.store.isBound;
    final pages = <Widget>[
      if (bound) ControlPage(api: _api) else const Center(child: Text('请先在设置中绑定')),
      if (bound) TestPage(api: _api) else const Center(child: Text('请先绑定')),
      if (bound) LogsPage(api: _api) else const Center(child: Text('请先绑定')),
      const LonghuAiPage(),
      SettingsPage(store: widget.store, onBound: _setApi),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('跟单神控')),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.play_circle), label: '跟单'),
          NavigationDestination(icon: Icon(Icons.science), label: '测试'),
          NavigationDestination(icon: Icon(Icons.article), label: '日志'),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: '龙虎ai'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
