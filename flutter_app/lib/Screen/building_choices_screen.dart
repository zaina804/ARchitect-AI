import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config.dart';
import '../providers/app_provider.dart';
import '../models/project.dart';
import 'render_screen.dart';

class BuildingChoicesScreen extends StatefulWidget {
  final String imagePath;
  final Map<String, dynamic>? bounds;

  const BuildingChoicesScreen({
    super.key,
    required this.imagePath,
    required this.bounds,
  });

  @override
  State<BuildingChoicesScreen> createState() => _BuildingChoicesScreenState();
}

class _BuildingChoicesScreenState extends State<BuildingChoicesScreen> {
  // ── Building types ────────────────────────────────────────────────────────
  // glb: null means it has sub-options (residential floors)
  static const List<Map<String, dynamic>> _types = [
    {
      'label':   'Single-story House',
      'labelAr': 'منزل طابق واحد',
      'glb':     'HOUSE1.glb',
      'icon':    Icons.home_rounded,
      'color':   Color(0xFF1A73E8),
    },
    {
      'label':   'Two-story House',
      'labelAr': 'منزل طابقين',
      'glb':     'HOUSE2.glb',
      'icon':    Icons.home_work_rounded,
      'color':   Color(0xFF0D47A1),
    },
    {
      'label':   'Residential Building',
      'labelAr': 'بناء سكني',
      'glb':     null, // triggers floor sub-selection
      'icon':    Icons.apartment_rounded,
      'color':   Color(0xFF00897B),
    },
    {
      'label':   'Hospital',
      'labelAr': 'مستشفى',
      'glb':     'Hospital.glb',
      'icon':    Icons.local_hospital_rounded,
      'color':   Color(0xFFD32F2F),
    },
    {
      'label':   'Cafe',
      'labelAr': 'كافيه',
      'glb':     'Cafe.glb',
      'icon':    Icons.local_cafe_rounded,
      'color':   Color(0xFF6D4C41),
    },
    {
      'label':   'Children School',
      'labelAr': 'مدرسة أطفال',
      'glb':     'children school.glb',
      'icon':    Icons.school_rounded,
      'color':   Color(0xFF7B1FA2),
    },
    {
      'label':   'Glass Skyscraper',
      'labelAr': 'ناطحة سحاب زجاجية',
      'glb':     'Glass skyscrapers.glb',
      'icon':    Icons.location_city_rounded,
      'color':   Color(0xFF00BCD4),
    },
  ];

  // Residential floors sub-options
  static const List<Map<String, dynamic>> _floors = [
    {'label': '4 Floors', 'labelAr': '٤ طوابق', 'glb': 'Residential building4.glb'},
    {'label': '5 Floors', 'labelAr': '٥ طوابق', 'glb': 'Residential building5.glb'},
    {'label': '6 Floors', 'labelAr': '٦ طوابق', 'glb': 'Residential building6.glb'},
  ];

  void _onTypeTap(BuildContext context, Map<String, dynamic> type, bool isAr) {
    final glb = type['glb'] as String?;
    if (glb == null) {
      // Residential → show floor picker
      _showFloorSheet(context, isAr);
    } else {
      _goToRender(context, glb, type['label'] as String);
    }
  }

  void _showFloorSheet(BuildContext context, bool isAr) {
    final isDark = context.read<AppProvider>().isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0D1A0D) : const Color(0xFFFFFAFA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF696969),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isAr ? 'اختر عدد الطوابق' : 'Select Number of Floors',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFDCDCDC) : const Color(0xFF2F4F4F),
              ),
            ),
            const SizedBox(height: 16),
            ..._floors.map((f) => _FloorTile(
              label: isAr ? f['labelAr']! as String : f['label']! as String,
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                _goToRender(context, f['glb']! as String,
                    isAr ? f['labelAr']! as String : f['label']! as String);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomGlb(BuildContext context, bool isAr) async {
    // FileType.any is required on Android — .glb has no registered MIME type
    // so FileType.custom with allowedExtensions:['glb'] shows an empty picker.
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;
    final filePath = result.files.single.path!;
    final fileName = result.files.single.name;
    if (!fileName.toLowerCase().endsWith('.glb')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAr
              ? 'الرجاء اختيار ملف بصيغة GLB فقط'
              : 'Please select a .glb file'),
          backgroundColor: Colors.redAccent,
        ));
      }
      return;
    }
    if (!context.mounted) return;
    await _uploadAndOpen(context, filePath, fileName, isAr);
  }

  Future<void> _uploadAndOpen(
      BuildContext context, String filePath, String fileName, bool isAr) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2535),
        content: Row(children: [
          const CircularProgressIndicator(color: Color(0xFF1A73E8)),
          const SizedBox(width: 16),
          Text(isAr ? 'جاري الرفع والضغط...' : 'Uploading & compressing…',
              style: const TextStyle(color: Colors.white)),
        ]),
      ),
    );
    try {
      final uri     = Uri.parse('$serverBaseUrl/upload-glb');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
          await http.MultipartFile.fromPath('file', filePath, filename: fileName));
      final streamed = await request.send().timeout(const Duration(minutes: 15));
      final body     = await streamed.stream.bytesToString();
      if (!context.mounted) return;
      Navigator.pop(context); // close loading dialog
      if (streamed.statusCode == 200) {
        final data         = jsonDecode(body) as Map<String, dynamic>;
        final savedName    = data['filename'] as String;
        final displayTitle = fileName.replaceAll('.glb', '');
        _goToRender(context, savedName, displayTitle);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isAr ? 'فشل الرفع' : 'Upload failed')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isAr ? 'خطأ: تأكد من تشغيل الخادم' : 'Error: make sure the server is running')));
      }
    }
  }

  void _goToRender(BuildContext context, String glbName, String title) {
    // Save project to persistent storage
    context.read<AppProvider>().addProject(Project(
      id:        DateTime.now().millisecondsSinceEpoch.toString(),
      title:     title,
      imagePath: widget.imagePath,
      glbName:   glbName,
      date:      DateTime.now(),
      bounds:    widget.bounds,
    ));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RenderScreen(
          imagePath: widget.imagePath,
          glbName:   glbName,
          bounds:    widget.bounds,
          title:     title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark   = provider.isDarkMode;
    final isAr     = provider.locale.languageCode == 'ar';

    const bgDark    = Color(0xFF0D1A0D);
    const bgLight   = Color(0xFFFFFAFA);
    const cardDark  = Color(0xFF1A2E1A);
    const cardLight = Color(0xFFDCDCDC);
    const textDark  = Color(0xFFDCDCDC);
    const textLight = Color(0xFF2F4F4F);

    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      appBar: AppBar(
        backgroundColor: isDark ? bgDark : bgLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: isDark ? textDark : textLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isAr ? 'اختر نوع المبنى' : 'Choose Building Type',
          style: TextStyle(
            color: isDark ? textDark : textLight,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: _types.length + 1, // +1 for custom GLB card
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  // Custom GLB upload card (last item)
                  if (i == _types.length) {
                    return GestureDetector(
                      onTap: () => _pickCustomGlb(context, isAr),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? cardDark : cardLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF43A047).withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF43A047).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.upload_file_rounded,
                                  color: Color(0xFF43A047), size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAr ? 'رفع ملف GLB خاص' : 'Upload Custom GLB',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? textDark : textLight,
                                    ),
                                  ),
                                  Text(
                                    isAr ? 'استخدم نموذج مبنى خاص بك' : 'Use your own 3D building model',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF696969)),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: Color(0xFF43A047)),
                          ],
                        ),
                      ),
                    );
                  }

                  final type          = _types[i];
                  final color         = type['color'] as Color;
                  final isResidential = type['glb'] == null;

                  return GestureDetector(
                    onTap: () => _onTypeTap(context, type, isAr),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: color.withOpacity(isDark ? 0.10 : 0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: color.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Icon
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(type['icon'] as IconData,
                                color: color, size: 26),
                          ),
                          const SizedBox(width: 14),

                          // Labels
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAr
                                      ? type['labelAr'] as String
                                      : type['label'] as String,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? textDark : textLight,
                                  ),
                                ),
                                if (isResidential)
                                  Text(
                                    isAr ? '٤ · ٥ · ٦ طوابق' : '4 · 5 · 6 floors',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: color.withOpacity(0.7)),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 6),
                          Icon(
                            isResidential
                                ? Icons.chevron_right_rounded
                                : Icons.arrow_forward_ios_rounded,
                            size: isResidential ? 22 : 14,
                            color: color.withOpacity(0.7),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Floor tile widget ─────────────────────────────────────────────────────────
class _FloorTile extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _FloorTile({required this.label, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF00897B).withOpacity(isDark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF00897B).withOpacity(0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.layers_rounded, color: Color(0xFF00897B), size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFDCDCDC) : const Color(0xFF2F4F4F),
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF00897B)),
          ],
        ),
      ),
    );
  }
}
