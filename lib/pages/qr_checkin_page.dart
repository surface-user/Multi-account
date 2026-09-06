import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/checkin_info.dart';
import '../state/app_state.dart';

/// 动态二维码签到页。
///
/// 扫码 UI 完全仿照 course_helper 的 ScanPage：全屏黑色背景、扫描框
/// [QrScanBoxPainter]、底部「相册 + 取消」。相机权限处理与错误兜底保留
/// （Android 16 上仍需显式授权 + 显式 start）。扫码/选图解析出签到信息后，
/// 以当前账户会话 Cookie 上报雨课堂。
class QRCheckinPage extends StatefulWidget {
  const QRCheckinPage({super.key});

  @override
  State<QRCheckinPage> createState() => _QRCheckinPageState();
}

class _QRCheckinPageState extends State<QRCheckinPage>
    with TickerProviderStateMixin {
  MobileScannerController? _controller;
  StreamSubscription<Object?>? _subscription;

  final int animationTime = 2000;
  AnimationController? _animationController;
  bool _isScan = true;

  CheckinInfo? _info;
  bool _handled = false;
  bool _submitting = false;
  String? _resultMessage;
  bool? _resultOk;

  // 相机是否仍在初始化（course_helper 用 _isInitializing 展示加载指示器）。
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  @override
  void dispose() {
    _animationController?.stop();
    _animationController?.dispose();
    _animationController = null;
    _subscription?.cancel();
    _controller?.stop();
    _controller?.dispose();
    _controller = null;
    _isScan = false;
    super.dispose();
  }

  Future<void> _initializeScanner() async {
    if (!mounted) {
      return;
    }
    // 完全参照 course_helper：不在 Flutter 侧用 permission_handler 预申请权限，
    // 而是交给 mobile_scanner 在 start() 时内部处理相机权限（自动弹系统授权框）。
    // 避免与 mobile_scanner 内部权限流程竞争，导致 Android 16 上相机开了但预览黑屏。
    try {
      _controller = MobileScannerController(
        autoStart: false,
        cameraResolution: const Size(1920, 1080),
        detectionSpeed: DetectionSpeed.unrestricted,
        formats: const [BarcodeFormat.qrCode],
        autoZoom: true,
      );
      await _controller!.start();
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        _startScan();
      }
    } catch (error) {
      debugPrint('camera start error: $error');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  void _startScan() {
    _isScan = true;
    _initAnimation();
  }

  void _initAnimation() {
    _animationController ??= AnimationController(
      vsync: this,
      duration: Duration(milliseconds: animationTime),
    )
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      })
      ..addStatusListener((state) {
        if (!mounted) {
          return;
        }
        if (state == AnimationStatus.completed) {
          Future.delayed(const Duration(seconds: 1), () {
            if (_animationController != null &&
                _animationController!.status != AnimationStatus.dismissed) {
              _animationController?.reverse();
            }
          });
        } else if (state == AnimationStatus.dismissed) {
          Future.delayed(const Duration(seconds: 1), () {
            if (_animationController != null &&
                _animationController!.status != AnimationStatus.forward) {
              _animationController?.forward();
            }
          });
        }
      });

    _animationController?.forward();
  }

  void _stop() {
    if (!_isScan) {
      return;
    }
    _isScan = false;
    _controller?.stop();
    _animationController?.stop();
    _animationController?.reset();
  }

  /// 从相册选图识别（相机失败/兜底，仿 course_helper 的 scanImage）。
  Future<void> _scanImage(String path) async {
    try {
      final BarcodeCapture? capture = await _controller?.analyzeImage(path);
      _stop();
      if (mounted && capture != null && capture.barcodes.isNotEmpty) {
        final code = capture.barcodes.first.rawValue;
        if (code != null) {
          _applyScanned(code);
        }
      } else {
        await _controller?.start();
        _startScan();
      }
    } catch (e) {
      debugPrint('Failed to analyze image: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) {
      return;
    }
    await _scanImage(image.path);
  }

  /// 处理已扫到的二维码内容（相机或相册通用）。
  ///
  /// 确认是雨课堂动态签到 URL 后立即上报，不再要求用户二次确认。
  /// 非雨课堂内容仍然只展示识别结果，避免误提交。
  void _applyScanned(String raw) {
    if (!mounted) {
      return;
    }
    _handled = true;
    final info = CheckinInfo.parse(raw);
    setState(() {
      _info = info;
      if (info.isUsable) {
        _resultMessage = null;
        _resultOk = null;
      } else if (info.raw.trim().isEmpty) {
        _resultMessage = '未解析出有效内容';
        _resultOk = false;
      } else {
        _resultMessage = '已识别到内容，但不是雨课堂签到二维码';
        _resultOk = false;
      }
    });

    if (info.isUsable) {
      unawaited(_submit());
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }
    String? raw;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        raw = barcode.rawValue;
        break;
      }
    }
    if (raw == null) {
      return;
    }
    _handled = true;
    _stop();
    _applyScanned(raw);
  }

  void _cancel() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _rescan() async {
    setState(() {
      _handled = false;
      _info = null;
      _resultOk = null;
      _resultMessage = null;
    });
    final controller = _controller;
    if (controller != null) {
      await controller.stop();
      await controller.start();
    }
    _startScan();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final info = _info;
    if (info == null) {
      return;
    }
    final validation = context.read<AppState>().checkin.validate(info);
    if (!validation.success) {
      setState(() {
        _resultOk = false;
        _resultMessage = validation.message;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _resultMessage = null;
    });

    final state = context.read<AppState>();
    final account = state.currentAccount;
    if (account == null) {
      setState(() {
        _submitting = false;
        _resultOk = false;
        _resultMessage = '当前没有账户';
      });
      return;
    }

    final cookie = await state.cookieOf(account.id);
    final result =
        await state.checkin.checkin(info, cookie ?? '', uid: account.id);

    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _resultOk = result.success;
      _resultMessage = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('扫码签到'),
      ),
      body: Stack(
        children: [
          _buildCamera(scheme),
          // 扫描信息结果面板（扫码成功后显示在底部）。
          if (_info != null) _buildResultPanel(scheme),
        ],
      ),
    );
  }

  Widget _buildCamera(ColorScheme scheme) {
    // 完全参照 course_helper：MobileScanner 挂载、初始化时显示加载指示器。
    // 不再用权限状态分支；权限/失败由 mobile_scanner 内部处理。
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),
        if (_isInitializing)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        // 扫描框（含动画扫描线）。
        Center(
          child: CustomPaint(
            painter: QrScanBoxPainter(
              boxLineColor: Theme.of(context).colorScheme.primary,
              animationValue: _animationController?.value ?? 0,
              isForward:
                  _animationController?.status == AnimationStatus.forward,
            ),
            child: const SizedBox(
              width: 240,
              height: 240,
            ),
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '将二维码放入框内',
                  style: TextStyle(
                    color: Colors.white,
                    backgroundColor: Colors.black54,
                  ),
                ),
              ),
            ),
          ),
        ),
        // 底部控件：相册 + 取消（仿 course_helper）。
        if (_info == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library,
                      color: Colors.white, size: 35),
                ),
                TextButton(
                  onPressed: _cancel,
                  child: const Text(
                    '取消',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResultPanel(ColorScheme scheme) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '签到信息',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildInfoChips(scheme),
            ),
            const SizedBox(height: 12),
            if (_submitting)
              const _SubmittingBanner()
            else if (_resultMessage != null)
              _ResultBanner(ok: _resultOk ?? false, message: _resultMessage!),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _rescan,
                    child: const Text('重新扫码'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: (_submitting ||
                            (_resultOk ?? false) ||
                            !(_info?.isUsable ?? false))
                        ? null
                        : _submit,
                    child: _submitting
                        ? const Text('自动签到中…')
                        : Text(!(_info?.isUsable ?? false)
                            ? '无法签到'
                            : (_resultOk ?? false)
                                ? '签到成功'
                                : '重试签到'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildInfoChips(ColorScheme scheme) {
    final info = _info!;
    final chips = <Widget>[];
    void add(String? label, String? value) {
      if (value == null || value.isEmpty) {
        return;
      }
      chips.add(Chip(
        avatar: const Icon(Icons.info_outline, size: 16),
        label: Text('$label: $value'),
        visualDensity: VisualDensity.compact,
      ));
    }

    add('班级', info.classId);
    add('签到ID', info.checkinId);
    add('签到码', info.checkinCode);
    add('类型', info.signInType);
    if (chips.isEmpty && info.raw.trim().isNotEmpty) {
      final raw = info.raw.trim();
      final shown = raw.length > 46 ? '${raw.substring(0, 46)}…' : raw;
      chips.add(Chip(
        avatar: const Icon(Icons.link, color: Colors.blue, size: 16),
        label: Text('已识别：$shown'),
        visualDensity: VisualDensity.compact,
      ));
    }
    if (chips.isEmpty) {
      chips.add(const Chip(
        avatar: Icon(Icons.warning_amber, color: Colors.orange, size: 16),
        label: Text('未解析出有效字段'),
      ));
    }
    return chips;
  }
}

/// 自定义扫描框绘制器（完全仿照 course_helper 的 QrScanBoxPainter）。
class QrScanBoxPainter extends CustomPainter {
  final double animationValue;
  final bool isForward;
  final Color boxLineColor;

  QrScanBoxPainter({
    required this.animationValue,
    required this.isForward,
    required this.boxLineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderRadius = const BorderRadius.all(Radius.circular(12)).toRRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    canvas.drawRRect(
      borderRadius,
      Paint()
        ..color = Colors.white54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path();
    // leftTop
    path.moveTo(0, 50);
    path.lineTo(0, 12);
    path.quadraticBezierTo(0, 0, 12, 0);
    path.lineTo(50, 0);
    // rightTop
    path.moveTo(size.width - 50, 0);
    path.lineTo(size.width - 12, 0);
    path.quadraticBezierTo(size.width, 0, size.width, 12);
    path.lineTo(size.width, 50);
    // rightBottom
    path.moveTo(size.width, size.height - 50);
    path.lineTo(size.width, size.height - 12);
    path.quadraticBezierTo(
        size.width, size.height, size.width - 12, size.height);
    path.lineTo(size.width - 50, size.height);
    // leftBottom
    path.moveTo(50, size.height);
    path.lineTo(12, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - 12);
    path.lineTo(0, size.height - 50);

    canvas.drawPath(path, borderPaint);

    canvas.clipRRect(
      const BorderRadius.all(Radius.circular(12)).toRRect(Offset.zero & size),
    );

    // 扫描线。
    final linePaint = Paint()
      ..color = boxLineColor
      ..strokeWidth = 2.0;
    final lineY = size.height * animationValue;
    canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), linePaint);
  }

  @override
  bool shouldRepaint(QrScanBoxPainter oldDelegate) =>
      animationValue != oldDelegate.animationValue;

  @override
  bool shouldRebuildSemantics(QrScanBoxPainter oldDelegate) =>
      animationValue != oldDelegate.animationValue;
}

class _SubmittingBanner extends StatelessWidget {
  const _SubmittingBanner();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('已识别雨课堂二维码，正在自动签到…')),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.ok, required this.message});

  final bool ok;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.green : Colors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.error, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
