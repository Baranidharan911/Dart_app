// ignore_for_file: sort_child_properties_last, prefer_const_constructors, use_key_in_widget_constructors, library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewPage extends StatefulWidget {
  final String url;

  const WebViewPage({required this.url});

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;
  Offset _offset = Offset(300, 600);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _isLoading = progress < 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onHttpError: (HttpResponseError error) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<bool> _handleWillPop() async {
    if (await controller.canGoBack()) {
      controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WillPopScope(
        onWillPop: _handleWillPop,
        child: Stack(
          children: [
            SafeArea(
              child: WebViewWidget(controller: controller),
            ),
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(),
              ),
            Positioned(
              left: _offset.dx,
              top: _offset.dy,
              child: Draggable(
                feedback: Material(
                  type: MaterialType.transparency,
                  child: FloatingActionButton(
                    onPressed: () {},
                    child: Image.asset(
                      'assets/logo.png', // Replace with your logo asset path
                      fit: BoxFit.cover,
                    ),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                ),
                childWhenDragging: Container(),
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Image.asset(
                    'assets/logo.png', // Replace with your logo asset path
                    fit: BoxFit.cover,
                  ),
                  backgroundColor: Colors.white,
                ),
                onDragEnd: (details) {
                  setState(() {
                    _offset = details.offset;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}