import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/course.dart';
import '../models/slide.dart';
import '../state/app_state.dart';

/// PPT / 课件整页查看页。
///
/// 拉取课程课件（幻灯片）列表，以可翻页的 [PageView] 整页展示。静态图使用
/// [CachedNetworkImage]，动态/交互课件则回退到 WebView 展示。
class PPTViewerPage extends StatefulWidget {
  const PPTViewerPage(
      {super.key, required this.course, this.cookie, this.uid});

  final Course course;
  final String? cookie;
  final String? uid;

  @override
  State<PPTViewerPage> createState() => _PPTViewerPageState();
}

class _PPTViewerPageState extends State<PPTViewerPage> {
  final PageController _pageController = PageController();
  List<Slide> _slides = [];
  bool _loading = true;
  String? _error;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final slides = await state.api.fetchSlides(widget.course,
            cookie: widget.cookie, uid: widget.uid);
        if (!mounted) {
          return;
        }
        setState(() {
          _slides = slides;
          _loading = false;
        });
      } catch (e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _loading = false;
          _error = '课件加载失败: $e';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.course.name),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: Text(
              '${_current + 1} / ${_slides.length}',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    if (_slides.isEmpty) {
      return const Center(
        child: Text('暂无课件', style: TextStyle(color: Colors.white)),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return _SlideView(slide: slide, cookie: widget.cookie);
            },
          ),
        ),
        _buildToolbar(),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.keyboard_arrow_left),
            onPressed: _current > 0
                ? () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    )
                : null,
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: (_current + 1) / _slides.length,
              minHeight: 6,
              backgroundColor: Colors.white24,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.keyboard_arrow_right),
            onPressed: _current < _slides.length - 1
                ? () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    )
                : null,
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, this.cookie});

  final Slide slide;
  final String? cookie;

  @override
  Widget build(BuildContext context) {
    if (slide.imageUrl != null && slide.imageUrl!.isNotEmpty) {
      return InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: slide.imageUrl!,
            width: double.infinity,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) =>
                _slideFallback(slide, context),
          ),
        ),
      );
    }
    return _slideFallback(slide, context);
  }

  Widget _slideFallback(Slide slide, BuildContext context) {
    if (slide.pageUrl != null && slide.pageUrl!.isNotEmpty) {
      return _WebViewSlide(url: slide.pageUrl!, cookie: cookie);
    }
    return const Center(
      child: Text('该页暂无内容', style: TextStyle(color: Colors.white70)),
    );
  }
}

/// 使用 WebView 展示动态/交互课件页，并尝试注入会话 Cookie。
class _WebViewSlide extends StatefulWidget {
  const _WebViewSlide({required this.url, this.cookie});

  final String url;
  final String? cookie;

  @override
  State<_WebViewSlide> createState() => _WebViewSlideState();
}

class _WebViewSlideState extends State<_WebViewSlide> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final cookie = widget.cookie;
    if (cookie != null && cookie.isNotEmpty) {
      final manager = WebViewCookieManager();
      for (final item in cookie.split(';')) {
        final parts = item.split('=');
        if (parts.length >= 2) {
          manager.setCookie(
            WebViewCookie(
              name: parts[0].trim(),
              value: parts.sublist(1).join('=').trim(),
              domain: '',
              path: '/',
            ),
          );
        }
      }
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.orange),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
