import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config.dart';
import '../models/chat_message.dart';
import '../providers/app_provider.dart';
import '../services/openai_service.dart';

// ─── Color presets ────────────────────────────────────────────────────────────
final _colorPresets = [
  {'hex': '#1A73E8', 'name': 'Blue'},
  {'hex': '#E53935', 'name': 'Red'},
  {'hex': '#FFFFFF', 'name': 'White'},
  {'hex': '#78909C', 'name': 'Gray'},
  {'hex': '#D4A96A', 'name': 'Beige'},
  {'hex': '#4CAF50', 'name': 'Green'},
];

Color _hexColor(String hex) =>
    Color(int.parse(hex.replaceFirst('#', '0xFF')));

// ─── Building footprint lookup ────────────────────────────────────────────────
const Map<String, String> _buildingFootprints = {
  'HOUSE1.glb':                 '~80–120 m² footprint, single story',
  'HOUSE2.glb':                 '~80–120 m² per floor, 2 floors (160–240 m² total)',
  'Residential building4.glb':  '~200–400 m² footprint, 4 floors',
  'Residential building5.glb':  '~200–400 m² footprint, 5 floors',
  'Residential building6.glb':  '~200–400 m² footprint, 6 floors',
  'Hospital.glb':               '~1000–2000 m² footprint',
  'Cafe.glb':                   '~60–100 m² footprint',
  'children school.glb':        '~500–800 m² footprint',
  'Glass skyscrapers.glb':      '~400–800 m² base footprint, skyscraper',
};

class RenderScreen extends StatefulWidget {
  final String imagePath;
  final String glbName;
  final Map<String, dynamic>? bounds;
  final String title;

  const RenderScreen({
    super.key,
    required this.imagePath,
    required this.glbName,
    required this.bounds,
    required this.title,
  });

  @override
  State<RenderScreen> createState() => _RenderScreenState();
}

class _RenderScreenState extends State<RenderScreen> {
  late final WebViewController _controller;
  bool _loading  = true;
  bool _chatOpen = false;
  bool _thinking = false;
  List<ChatMessage> _messages = [];
  final TextEditingController _textCtrl   = TextEditingController();
  final ScrollController      _scrollCtrl = ScrollController();

  static const _quickActions = [
    {'en': 'Is this building good for my land?',       'ar': 'هل هذا المبنى مناسب لأرضي؟'},
    {'en': 'What are the building costs in Jordan?',   'ar': 'ما هي تكاليف البناء في الأردن؟'},
    {'en': 'What cement type should I use?',           'ar': 'ما نوع الإسمنت المناسب؟'},
    {'en': 'Is a bigger building better for my land?', 'ar': 'هل مبنى أكبر أفضل لأرضي؟'},
  ];

  // ── Land info for chat context ───────────────────────────────────────────────

  String _buildLandInfo(String lang) {
    final bounds = widget.bounds;
    if (bounds == null) return '';

    final polygon    = bounds['polygon'] as List<dynamic>?;
    final bboxW      = (bounds['width']  as num?)?.toDouble() ?? 0.0;
    final bboxH      = (bounds['height'] as num?)?.toDouble() ?? 0.0;
    double area      = 0;
    if (polygon != null && polygon.length >= 3) {
      final n = polygon.length;
      for (int i = 0; i < n; i++) {
        final j = (i + 1) % n;
        final p = polygon[i] as List<dynamic>;
        final q = polygon[j] as List<dynamic>;
        area += (p[0] as num).toDouble() * (q[1] as num).toDouble();
        area -= (q[0] as num).toDouble() * (p[1] as num).toDouble();
      }
      area = area.abs() / 2;
    } else {
      area = bboxW * bboxH;
    }

    // Estimate square meters: assume phone photo covers 8–40m in width
    // (close shot ~8m, typical ~20m, far ~40m)
    final estClose  = (area * 48).round();   // 8m × 6m image
    final estMid    = (area * 300).round();  // 20m × 15m image
    final estFar    = (area * 1200).round(); // 40m × 30m image

    final footprint = _buildingFootprints[widget.glbName] ??
        'standard building footprint';

    final pct = (area * 100).toStringAsFixed(1);
    final bw  = (bboxW  * 100).toStringAsFixed(0);
    final bh  = (bboxH  * 100).toStringAsFixed(0);

    if (lang == 'ar') {
      return '''===بيانات حدود الأرض المكتشفة بالذكاء الاصطناعي===
- نسبة مضلع الأرض: $pct% من مساحة الصورة
- أبعاد الإطار المحيط: $bw% عرض × $bh% ارتفاع من الصورة
- تقدير المساحة بالمتر المربع (حسب بُعد التصوير):
  • تصوير قريب (8م): ~$estClose م²
  • تصوير متوسط (20م): ~$estMid م²
  • تصوير بعيد (40م): ~$estFar م²
- المبنى المختار: "${widget.title}" ($footprint)
- ملاحظة: الأرقام تقديرية لأن الحجم الحقيقي يعتمد على ارتفاع الكاميرا وزاويتها. قد يكون نموذج الذكاء الاصطناعي غير دقيق 100%.

عند سؤال المستخدم عن مساحة أرضه:
1. أخبره بالتقديرات الثلاث أعلاه مباشرة
2. اشرح أن الدقة تعتمد على بُعد التصوير
3. اسأله: "هل تعرف تقريباً بُعد الكاميرا عن الأرض؟ أو طول/عرض الأرض؟" لتحسين الحساب
4. قارن مساحة الأرض بمساحة أساس المبنى وأخبره إذا كان المبنى مناسباً''';
    } else {
      return '''=== AI-Detected Land Boundary Data ===
- Land polygon: $pct% of photo area
- Bounding box: $bw% wide × $bh% tall of photo
- Estimated area (depends on photo distance):
  • Close shot (~8m away): ~$estClose m²
  • Typical shot (~20m away): ~$estMid m²
  • Far shot (~40m away): ~$estFar m²
- Chosen building: "${widget.title}" ($footprint)
- Note: Estimates only — exact area depends on camera height and distance. AI detection may not be 100% accurate.

IMPORTANT — When the user asks about their land area or boundaries:
1. Immediately state the three area estimates above
2. Explain accuracy depends on how far they stood when taking the photo
3. Ask: "Do you know how far you were from the land, or its approximate length/width?" to improve the calculation
4. Compare land area vs building footprint and advise if the building fits''';
    }
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _injectViewer(),
      ))
      ..loadFlutterAsset('assets/viewer.html');
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── WebView ──────────────────────────────────────────────────────────────────

  Future<void> _injectViewer() async {
    try {
      final glbUrl     = '$modelsUrl/${Uri.encodeComponent(widget.glbName)}';
      final boundsJson = widget.bounds != null
          ? jsonEncode(widget.bounds)
          : 'null';
      await _controller.runJavaScript(
          'initViewer("$glbUrl", null, $boundsJson, "${widget.title}")');
      if (mounted) {
        final pad = MediaQuery.of(context).padding.bottom.toInt();
        await _controller.runJavaScript('setFlutterBottomInset($pad)');
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Chat ─────────────────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _thinking) return;
    final lang = context.read<AppProvider>().locale.languageCode;
    _textCtrl.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _thinking = true;
    });
    _scrollToBottom();

    try {
      // Use building command service so the AI can both advise AND control the 3D model
      final result = await OpenAIService.sendBuildingCommand(
        userMessage:   text,
        lang:          lang,
        buildingTitle: widget.title,
        landInfo:      _buildLandInfo(lang),
      );

      final reply    = result['response'] as String? ?? '';
      final commands = result['commands'] as List<dynamic>? ?? [];

      // Execute any 3D commands the AI returned (color changes, zoom, etc.)
      for (final cmd in commands) {
        if (cmd is Map<String, dynamic>) {
          _js(cmd);
        }
      }

      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: reply));
        _thinking = false;
      });
    } catch (_) {
      final lang2 = context.read<AppProvider>().locale.languageCode;
      setState(() {
        _messages.add(ChatMessage(
          role:    'assistant',
          content: lang2 == 'ar'
              ? 'حدث خطأ، حاول مجدداً.'
              : 'An error occurred. Please try again.',
        ));
        _thinking = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── 3D Commands ──────────────────────────────────────────────────────────────

  void _js(Map<String, dynamic> cmd) =>
      _controller.runJavaScript('applyCommandObj(${jsonEncode(cmd)})');

  void _showColorPicker(bool isAr) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2535),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAr ? 'اختر لوناً' : 'Choose a color',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: _colorPresets.map((p) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _showTargetPicker(isAr, p['hex']!);
                  },
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _hexColor(p['hex']!),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 1.5),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showTargetPicker(bool isAr, String hex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2535),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAr ? 'تطبيق على:' : 'Apply to:',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _TargetBtn(
                  label: isAr ? 'الجدران' : 'Walls',
                  icon:  Icons.foundation_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    _js({'action': 'changeColor', 'target': 'walls', 'color': hex});
                  },
                ),
                _TargetBtn(
                  label: isAr ? 'السقف' : 'Roof',
                  icon:  Icons.roofing_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    _js({'action': 'changeColor', 'target': 'roof', 'color': hex});
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAr      = context.watch<AppProvider>().locale.languageCode == 'ar';
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    final safePad   = MediaQuery.of(context).padding.bottom;
    final panelH    = MediaQuery.of(context).size.height * 0.52;
    final bottomPad = safePad;
    // When keyboard is open, lift panel above it; otherwise sit at safe area bottom
    final panelBottom = _chatOpen ? keyboardH : -panelH;
    const toolH     = 64.0;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),

          if (_loading)
            const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A73E8))),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),

          // Home button — jump directly to main screen
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 60,
            child: GestureDetector(
              onTap: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.home_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),

          // Edit toolbar — hides when chat opens
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            bottom: _chatOpen ? -toolH : bottomPad,
            left: 0, right: 0, height: toolH,
            child: _EditToolbar(
              isAr:       isAr,
              onColorTap: () => _showColorPicker(isAr),
              onZoomIn:   () => _js({'action': 'zoom', 'level': 'in'}),
              onZoomOut:  () => _js({'action': 'zoom', 'level': 'out'}),
              onReset:    () => _js({'action': 'resetColors'}),
            ),
          ),

          // Chat FAB
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            bottom: _chatOpen ? panelH + keyboardH + 12 : toolH + bottomPad + 12,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => setState(() => _chatOpen = !_chatOpen),
              backgroundColor: const Color(0xFF1A73E8),
              child: Icon(_chatOpen ? Icons.close : Icons.chat_rounded,
                  color: Colors.white),
            ),
          ),

          // Chat panel — lifts above keyboard when open
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            bottom: panelBottom,
            left: 0, right: 0, height: panelH,
            child: _ChatPanel(
              isAr:         isAr,
              messages:     _messages,
              thinking:     _thinking,
              textCtrl:     _textCtrl,
              scrollCtrl:   _scrollCtrl,
              quickActions: _quickActions,
              onSend:       _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Edit Toolbar (color + zoom only, no add-objects) ────────────────────────

class _EditToolbar extends StatelessWidget {
  final bool isAr;
  final VoidCallback onColorTap;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  const _EditToolbar({
    required this.isAr,
    required this.onColorTap,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xCC0F1623),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TBtn(
                icon: Icons.palette_rounded,
                label: isAr ? 'لون' : 'Color',
                onTap: onColorTap),
            const SizedBox(width: 8),
            Container(width: 1, height: 32, color: Colors.white12),
            const SizedBox(width: 8),
            _TBtn(
                icon: Icons.zoom_in_rounded,
                label: isAr ? 'تكبير' : 'Zoom+',
                onTap: onZoomIn),
            _TBtn(
                icon: Icons.zoom_out_rounded,
                label: isAr ? 'تصغير' : 'Zoom-',
                onTap: onZoomOut),
            const SizedBox(width: 8),
            Container(width: 1, height: 32, color: Colors.white12),
            const SizedBox(width: 8),
            _TBtn(
                icon: Icons.refresh_rounded,
                label: isAr ? 'إعادة' : 'Reset',
                onTap: onReset),
          ],
        ),
      ),
    );
  }
}

class _TBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _TBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _TargetBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _TargetBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A73E8).withAlpha(30),
          border: Border.all(color: const Color(0xFF1A73E8)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF1A73E8), size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF1A73E8), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─── Chat Panel ───────────────────────────────────────────────────────────────

class _ChatPanel extends StatelessWidget {
  final bool isAr;
  final List<ChatMessage> messages;
  final bool thinking;
  final TextEditingController textCtrl;
  final ScrollController scrollCtrl;
  final List<Map<String, String>> quickActions;
  final void Function(String) onSend;

  const _ChatPanel({
    required this.isAr,
    required this.messages,
    required this.thinking,
    required this.textCtrl,
    required this.scrollCtrl,
    required this.quickActions,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1623),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 4)
        ],
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: Color(0xFF1A73E8), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAr ? 'مستشار البناء' : 'Building Advisor',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Messages
          Expanded(
            child: messages.isEmpty
                ? _QuickActions(
                    isAr: isAr, actions: quickActions, onTap: onSend)
                : ListView.builder(
                    controller: scrollCtrl,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: messages.length + (thinking ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == messages.length)
                        return const _TypingIndicator();
                      return _Bubble(
                          role: messages[i].role,
                          content: messages[i].content);
                    },
                  ),
          ),
          _InputBar(isAr: isAr, controller: textCtrl, onSend: onSend),
        ],
      ),
    );
  }
}

// ─── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final bool isAr;
  final List<Map<String, String>> actions;
  final void Function(String) onTap;
  const _QuickActions(
      {required this.isAr, required this.actions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.architecture, color: Colors.white24, size: 40),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'اسألني عن مبناك وأرضك في الأردن'
                : 'Ask me about your building & land in Jordan',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: actions.map((qa) {
              final label = isAr ? qa['ar']! : qa['en']!;
              return GestureDetector(
                onTap: () => onTap(label),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1A73E8)),
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFF1A73E8).withAlpha(30),
                  ),
                  child: Text(label,
                      style: const TextStyle(
                          color: Color(0xFF1A73E8), fontSize: 12)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final String role;
  final String content;
  const _Bubble({required this.role, required this.content});

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF1A73E8)
              : const Color(0xFF1E2535),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight:
                isUser ? const Radius.circular(4) : null,
            bottomLeft: isUser ? null : const Radius.circular(4),
          ),
        ),
        child: Text(content,
            style:
                const TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }
}

// ─── Typing Indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF1E2535),
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(delay: 0),
            SizedBox(width: 4),
            _Dot(delay: 200),
            SizedBox(width: 4),
            _Dot(delay: 400),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: const CircleAvatar(
            radius: 3, backgroundColor: Colors.white54),
      );
}

// ─── Input Bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final bool isAr;
  final TextEditingController controller;
  final void Function(String) onSend;
  const _InputBar(
      {required this.isAr,
      required this.controller,
      required this.onSend});

  @override
  Widget build(BuildContext context) {
    // Panel is already lifted above the keyboard by the parent AnimatedPositioned,
    // so we only need safe-area padding here (not viewInsets again).
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 8,
        bottom: safeBottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: isAr
                    ? 'اسأل عن مبناك...'
                    : 'Ask about your building...',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF1E2535),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: onSend,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onSend(controller.text),
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                  color: Color(0xFF1A73E8), shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
