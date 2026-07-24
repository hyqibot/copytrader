import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 内嵌展示腾讯元器「幻银超i」对话页（外链）。
class HuanyinChaoiPage extends StatefulWidget {
  const HuanyinChaoiPage({super.key});

  static const url =
      'https://yuanqi.tencent.com/webim/#/chat/CzpBJG?appid=1964915414829204096&experience=true';

  @override
  State<HuanyinChaoiPage> createState() => _HuanyinChaoiPageState();
}

class _HuanyinChaoiPageState extends State<HuanyinChaoiPage> {
  late final WebViewController _controller;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _error = null;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = err.description;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(HuanyinChaoiPage.url));
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_error != null)
          ColoredBox(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              dense: true,
              title: Text('加载失败：$_error'),
              trailing: TextButton(onPressed: _reload, child: const Text('重试')),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_loading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ],
    );
  }
}
