import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config.dart';
import '../providers/app_provider.dart';
import 'land_preview_screen.dart';

class ScanScreen extends StatefulWidget {
  final String imagePath;
  const ScanScreen({super.key, required this.imagePath});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  late AnimationController _scanCtrl;
  late Animation<double>   _scanAnim;

  int    _msgIndex = 0;
  Timer? _msgTimer;

  static const _messagesEn = [
    'Initializing AI model...',
    'Scanning for empty land...',
    'Analyzing land boundaries...',
    'Computing land geometry...',
    'Finalizing results...',
  ];

  static const _messagesAr = [
    'تهيئة نموذج الذكاء الاصطناعي...',
    'البحث عن الأرض الفارغة...',
    'تحليل حدود الأرض...',
    'حساب هندسة الأرض...',
    'استكمال النتائج...',
  ];

  @override
  void initState() {
    super.initState();

    // Scan line animation — sweeps top → bottom, repeating
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _scanAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _scanCtrl, curve: Curves.linear));

    // Cycle status messages every 900 ms
    _msgTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) setState(() => _msgIndex = (_msgIndex + 1) % _messagesEn.length);
    });

    _runDetection();
  }

  @override
  void dispose() {
    _msgTimer?.cancel();
    _scanCtrl.dispose();
    super.dispose();
  }

  // Resize image to 640×480 PNG — YOLO model expects this exact format
  Future<List<int>> _resizeForYolo(String path) async {
    final raw   = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(
        raw, targetWidth: 640, targetHeight: 480);
    final frame = await codec.getNextFrame();
    final bd    = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    return bd!.buffer.asUint8List();
  }

  Future<void> _runDetection() async {
    final start = DateTime.now();
    bool?  isEmpty;
    double conf   = 0.0;
    Map<String, dynamic>? bounds;
    String? errorMsg;

    try {
      // Try to resize; fall back to original bytes if that fails
      List<int> bytes;
      try {
        bytes = await _resizeForYolo(widget.imagePath);
      } catch (_) {
        bytes = await File(widget.imagePath).readAsBytes();
      }

      final request = http.MultipartRequest('POST', Uri.parse(detectUrl));
      request.files.add(http.MultipartFile.fromBytes(
          'file', bytes, filename: 'land.png'));
      final streamed =
          await request.send().timeout(const Duration(seconds: 45));
      final body = await streamed.stream.bytesToString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Parse result — if keys missing, treat as server error
      if (data['is_empty_land'] == null) {
        errorMsg = 'Unexpected server response: $body';
      } else {
        isEmpty = data['is_empty_land'] as bool;
        conf    = (data['confidence'] as num? ?? 0).toDouble();
        bounds  = data['bounds'] as Map<String, dynamic>?;
      }
    } catch (e) {
      errorMsg = e.toString();
    }

    // Always show animation for at least 2.5 s so it doesn't flash by
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    if (elapsed < 2500) {
      await Future.delayed(Duration(milliseconds: 2500 - elapsed));
    }

    if (!mounted) return;

    _msgTimer?.cancel();
    _scanCtrl.stop();

    if (errorMsg != null || isEmpty == null) {
      _showError(errorMsg);
      return;
    }

    if (isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LandPreviewScreen(
            imagePath:  widget.imagePath,
            confidence: conf,
            bounds:     bounds,
          ),
        ),
      );
    } else {
      _showNotEmpty();
    }
  }

  void _showError([String? detail]) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Detection Error'),
          ],
        ),
        content: Text(
          'Could not get a result from the server.\n\n'
          'Make sure:\n'
          '• Server is running (uvicorn server:app)\n'
          '• Phone and PC are on the same WiFi'
          '${detail != null ? '\n\nDetail: $detail' : ''}',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNotEmpty() {
    final isAr = context.read<AppProvider>().locale.languageCode == 'ar';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Text(isAr ? 'الأرض مشغولة' : 'Land Not Empty',
                style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          isAr
              ? 'هذه الأرض تبدو مشغولة.\nالرجاء التقاط صورة أخرى.'
              : 'This land appears to be occupied.\nPlease retake the photo.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(isAr ? 'إعادة التصوير' : 'Retake'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().locale.languageCode == 'ar';
    final messages = isAr ? _messagesAr : _messagesEn;

    return PopScope(
      canPop: false, // prevent accidental back during scanning
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Photo background ──────────────────────────────────────────
            Positioned.fill(
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.contain,
              ),
            ),

            // ── Animated scan overlay ─────────────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scanAnim,
                builder: (_, __) => CustomPaint(
                  painter: _ScanPainter(progress: _scanAnim.value),
                ),
              ),
            ),

            // ── Top gradient ──────────────────────────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 150,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // ── Bottom gradient ───────────────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 220,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // ── Top centre badge ──────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: const Color(0xFF1A73E8).withOpacity(0.50)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.psychology_rounded,
                            color: Color(0xFF1A73E8), size: 16),
                        const SizedBox(width: 7),
                        Text(
                          isAr ? 'نموذج الذكاء الاصطناعي يعمل'
                               : 'AI Model Running',
                          style: const TextStyle(
                            color: Color(0xFF1A73E8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom status panel ───────────────────────────────────────
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsing dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (i) => _PulseDot(
                              delay: Duration(milliseconds: i * 240)),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Cycling message with crossfade
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: Text(
                          messages[_msgIndex],
                          key: ValueKey(_msgIndex),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isAr ? 'يرجى الانتظار...' : 'Please wait...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.40),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Pulsing dot indicator
// ═══════════════════════════════════════════════════════════════════════════════
class _PulseDot extends StatefulWidget {
  final Duration delay;
  const _PulseDot({required this.delay});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 860),
    );
    _anim = Tween<double>(begin: 0.25, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 9, height: 9,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(
            const Color(0xFF1A73E8).withOpacity(0.30),
            const Color(0xFF00E676),
            _anim.value,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Scan line CustomPainter
// ═══════════════════════════════════════════════════════════════════════════════
class _ScanPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0 (top → bottom)

  const _ScanPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = progress * size.height;

    // Subtle blue tint over already-scanned region
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, y),
      Paint()..color = const Color(0xFF1A73E8).withOpacity(0.06),
    );

    // Glow gradient just above the line
    final glowH   = 90.0;
    final glowTop = max(0.0, y - glowH);
    final glowRect = Rect.fromLTWH(0, glowTop, size.width, y - glowTop);
    if (glowRect.height > 0) {
      canvas.drawRect(
        glowRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF00E676).withOpacity(0.18),
              const Color(0xFF00E676).withOpacity(0.42),
            ],
          ).createShader(glowRect),
      );
    }

    // Main scan line
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = const Color(0xFF00E676)
        ..strokeWidth = 2.2,
    );

    // Small bright dots sitting on the line
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.85);
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(size.width * i / 5.0, y), 2.8, dotPaint);
    }

    // Corner scan brackets (always visible)
    _bracket(canvas, Offset(22, 22), 1, 1);
    _bracket(canvas, Offset(size.width - 22, 22), -1, 1);
    _bracket(canvas, Offset(22, size.height - 22), 1, -1);
    _bracket(canvas, Offset(size.width - 22, size.height - 22), -1, -1);
  }

  void _bracket(Canvas canvas, Offset o, double dx, double dy) {
    const len = 22.0;
    final p = Paint()
      ..color = const Color(0xFF00E676).withOpacity(0.80)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(o, Offset(o.dx + dx * len, o.dy), p);
    canvas.drawLine(o, Offset(o.dx, o.dy + dy * len), p);
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.progress != progress;
}
