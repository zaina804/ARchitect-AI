import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/project.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'scan_screen.dart';
import 'render_screen.dart';
import 'chatbot_screen.dart';
import 'ar_view_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Open the AI scan screen which handles detection ───────────────────────
  void _handlePhoto(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanScreen(imagePath: path)),
    );
  }

  // ── Image source picker ───────────────────────────────────────────────────
  void _showImageSourceSheet(BuildContext context) {
    final provider = context.read<AppProvider>();
    final isAr     = provider.locale.languageCode == 'ar';
    final isDark   = provider.isDarkMode;

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
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF696969),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isAr ? 'اختر المصدر' : 'Select Source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFDCDCDC) : const Color(0xFF2F4F4F),
              ),
            ),
            const SizedBox(height: 20),

            // ── AR Mode (full-width banner) ───────────────────────────────
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ArViewScreen()),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF004D40), Color(0xFF00C853)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x5500C853),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.view_in_ar_rounded,
                        color: Colors.white, size: 38),
                    const SizedBox(height: 8),
                    Text(
                      isAr ? 'وضع AR المباشر' : 'AR Mode',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAr
                          ? 'اكتشاف الأرض تلقائياً عبر الكاميرا'
                          : 'Auto-detect land live with camera',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Camera + Gallery (row) ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      final photo = await ImagePicker()
                          .pickImage(source: ImageSource.camera);
                      if (photo != null) _handlePhoto(photo.path);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF1A73E8).withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.camera_alt_rounded,
                              color: Color(0xFF1A73E8), size: 34),
                          const SizedBox(height: 8),
                          Text(
                            isAr ? 'الكاميرا' : 'Camera',
                            style: const TextStyle(
                                color: Color(0xFF1A73E8),
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isAr ? 'التقط صورة' : 'Take photo',
                            style: const TextStyle(
                                color: Color(0xFF1A73E8),
                                fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      final photo = await ImagePicker()
                          .pickImage(source: ImageSource.gallery);
                      if (photo != null) _handlePhoto(photo.path);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF00BCD4).withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.photo_library_rounded,
                              color: Color(0xFF00BCD4), size: 34),
                          const SizedBox(height: 8),
                          Text(
                            isAr ? 'المعرض' : 'Gallery',
                            style: const TextStyle(
                                color: Color(0xFF00BCD4),
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isAr ? 'اختر صورة' : 'Pick photo',
                            style: const TextStyle(
                                color: Color(0xFF00BCD4),
                                fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Map glbName to color ──────────────────────────────────────────────────
  Color _colorForGlb(String glbName) {
    final n = glbName.toLowerCase();
    if (n.contains('house1'))       return Colors.blue.shade700;
    if (n.contains('house2'))       return Colors.blue.shade900;
    if (n.contains('residential'))  return Colors.teal.shade700;
    if (n.contains('hotel'))        return Colors.amber.shade800;
    if (n.contains('hospital'))     return Colors.red.shade700;
    if (n.contains('cafe'))         return Colors.brown.shade700;
    if (n.contains('school'))       return Colors.purple.shade700;
    if (n.contains('glass'))        return Colors.cyan.shade700;
    if (n.contains('mosque'))       return Colors.green.shade800;
    return Colors.blueGrey.shade700;
  }

  IconData _iconForGlb(String glbName) {
    final n = glbName.toLowerCase();
    if (n.contains('house'))        return Icons.home_rounded;
    if (n.contains('residential'))  return Icons.apartment_rounded;
    if (n.contains('hotel'))        return Icons.hotel_rounded;
    if (n.contains('hospital'))     return Icons.local_hospital_rounded;
    if (n.contains('cafe'))         return Icons.local_cafe_rounded;
    if (n.contains('school'))       return Icons.school_rounded;
    if (n.contains('glass'))        return Icons.location_city_rounded;
    if (n.contains('mosque'))       return Icons.place_rounded;
    return Icons.home_work_rounded;
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }

  void _confirmDelete(BuildContext context, String projectId, bool isAr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            Text(isAr ? 'حذف المشروع' : 'Delete Project',
                style: const TextStyle(fontSize: 17)),
          ],
        ),
        content: Text(
          isAr ? 'هل أنت متأكد أنك تريد حذف هذا المشروع؟'
               : 'Are you sure you want to remove this project?',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppProvider>().removeProject(projectId);
            },
            child: Text(isAr ? 'حذف' : 'Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark   = provider.isDarkMode;
    final isAr     = provider.locale.languageCode == 'ar';
    final projects = provider.projects;
    final sw       = MediaQuery.of(context).size.width;
    final sh       = MediaQuery.of(context).size.height;

    const bgDark    = Color(0xFF0D1A0D);
    const bgLight   = Color(0xFFFFFAFA);
    const cardDark  = Color(0xFF1A2E1A);
    const cardLight = Color(0xFFDCDCDC);
    const textDark  = Color(0xFFDCDCDC);
    const textLight = Color(0xFF2F4F4F);

    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      endDrawer: Drawer(
        backgroundColor: isDark ? cardDark : bgLight,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(sw * 0.06),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Color(0xFF1A73E8),
                  child: Icon(Icons.person, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(provider.userName,
                    style: TextStyle(
                      fontSize: sw * 0.045,
                      fontWeight: FontWeight.bold,
                      color: isDark ? textDark : textLight,
                    )),
                Text(provider.userEmail,
                    style: TextStyle(
                      fontSize: sw * 0.033,
                      color: const Color(0xFF696969),
                    )),
                const SizedBox(height: 8),
                Divider(
                    color: isDark
                        ? Colors.white12
                        : const Color(0xFF696969).withOpacity(0.3)),
                const SizedBox(height: 8),
                _ProfileOption(
                  icon: Icons.person_rounded,
                  label: isAr ? 'ملفي الشخصي' : 'My Profile',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  },
                ),
                const SizedBox(height: 12),
                _ProfileOption(
                  icon: Icons.settings_rounded,
                  label: isAr ? 'الإعدادات' : 'Settings',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()));
                  },
                ),
                const SizedBox(height: 12),
                _ProfileOption(
                  icon: Icons.psychology_rounded,
                  label: isAr ? 'المساعد الذكي' : 'AI Assistant',
                  isDark: isDark,
                  color: const Color(0xFF1A73E8),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const ChatbotScreen()));
                  },
                ),
                const Spacer(),
                _ProfileOption(
                  icon: Icons.logout_rounded,
                  label: isAr ? 'تسجيل الخروج' : 'Log Out',
                  isDark: isDark,
                  color: Colors.redAccent,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Builder(
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: sw * 0.05, vertical: sh * 0.02),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Header ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ARchitect AI',
                              style: TextStyle(
                                fontSize: sw * 0.055,
                                fontWeight: FontWeight.bold,
                                color: isDark ? textDark : textLight,
                              )),
                          Text(
                            isAr
                                ? 'الذكاء الاصطناعي للتصميم المعماري'
                                : 'AR Edition — Augmented Reality',
                            style: TextStyle(
                              fontSize: sw * 0.030,
                              color: const Color(0xFF1A73E8),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Scaffold.of(ctx).openEndDrawer(),
                        child: CircleAvatar(
                          backgroundColor: isDark ? cardDark : cardLight,
                          child: Icon(Icons.person,
                              color: isDark ? textDark : textLight),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: sh * 0.025),

                  // ─── Banner Card ───
                  AspectRatio(
                    aspectRatio: 16 / 7,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: cardDark,
                      ),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              image: const DecorationImage(
                                image: AssetImage('assets/images/51.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.72),
                                  Colors.transparent,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(sw * 0.05),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isAr ? 'هل أنت مستعد للبناء؟' : 'Ready to Build?',
                                  style: TextStyle(
                                    fontSize: sw * 0.048,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isAr
                                      ? 'صوّر أرضك وضع المبنى عليها بتقنية AR.'
                                      : 'Scan your land and place buildings in AR.',
                                  style: TextStyle(
                                      fontSize: sw * 0.028,
                                      color: Colors.white70),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _showImageSourceSheet(ctx),
                                  icon: const Icon(Icons.camera_alt, size: 16),
                                  label: Text(
                                    isAr ? 'امسح الأرض الآن' : 'Scan Land Now',
                                    style: TextStyle(fontSize: sw * 0.032),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A73E8),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: sw * 0.04,
                                        vertical: sh * 0.012),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: sh * 0.025),

                  // ─── Active Projects Stat ───
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(sw * 0.04),
                    decoration: BoxDecoration(
                      color: isDark ? cardDark : cardLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isDark
                              ? Colors.white12
                              : const Color(0xFF696969).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.folder_copy_rounded,
                            color: const Color(0xFF1A73E8), size: sw * 0.07),
                        SizedBox(width: sw * 0.03),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${projects.length}',
                              style: TextStyle(
                                fontSize: sw * 0.06,
                                fontWeight: FontWeight.bold,
                                color: isDark ? textDark : textLight,
                              ),
                            ),
                            Text(
                              isAr ? 'المشاريع النشطة' : 'Active Projects',
                              style: TextStyle(
                                fontSize: sw * 0.03,
                                color: const Color(0xFF696969),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: sh * 0.03),

                  // ─── Recent Projects ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isAr ? 'المشاريع الأخيرة' : 'Recent Projects',
                        style: TextStyle(
                          fontSize: sw * 0.042,
                          fontWeight: FontWeight.bold,
                          color: isDark ? textDark : textLight,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: sh * 0.012),

                  // Project list or empty state
                  if (projects.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: sh * 0.06),
                      decoration: BoxDecoration(
                        color: isDark ? cardDark : cardLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : const Color(0xFF696969).withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.folder_open_rounded,
                              size: sw * 0.12, color: const Color(0xFF696969)),
                          SizedBox(height: sh * 0.015),
                          Text(
                            isAr
                                ? 'لا توجد مشاريع بعد.\nامسح أرضك الأولى!'
                                : 'No projects yet.\nScan your first land!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF696969)),
                          ),
                        ],
                      ),
                    )
                  else
                    ...projects.take(10).map((p) => Padding(
                          padding: EdgeInsets.only(bottom: sh * 0.012),
                          child: _ProjectCard(
                            project: p,
                            isDark: isDark,
                            color: _colorForGlb(p.glbName),
                            icon: _iconForGlb(p.glbName),
                            dateStr: _formatDate(p.date),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RenderScreen(
                                  imagePath: p.imagePath,
                                  glbName: p.glbName,
                                  bounds: p.bounds,
                                  title: p.title,
                                ),
                              ),
                            ),
                            onDelete: () => _confirmDelete(context, p.id, isAr),
                          ),
                        )),

                  SizedBox(height: sh * 0.02),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Profile Option ────────────────────────────────────────────────────────────
class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool isDark;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (isDark ? const Color(0xFFDCDCDC) : const Color(0xFF2F4F4F));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A2E1A).withOpacity(0.7)
              : const Color(0xFFDCDCDC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    fontSize: 15, color: c, fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 14, color: c.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

// ── Project Card (real projects) ─────────────────────────────────────────────
class _ProjectCard extends StatelessWidget {
  final Project project;
  final bool isDark;
  final Color color;
  final IconData icon;
  final String dateStr;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.isDark,
    required this.color,
    required this.icon,
    required this.dateStr,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(sw * 0.03),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2E1A) : const Color(0xFFDCDCDC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark
                  ? Colors.white12
                  : const Color(0xFF696969).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Thumbnail or color icon
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: File(project.imagePath).existsSync()
                  ? Image.file(
                      File(project.imagePath),
                      width: sw * 0.14,
                      height: sw * 0.14,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: sw * 0.14,
                      height: sw * 0.14,
                      color: color,
                      child: Icon(icon, color: Colors.white54, size: 28),
                    ),
            ),
            SizedBox(width: sw * 0.035),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    style: TextStyle(
                      fontSize: sw * 0.038,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFFDCDCDC)
                          : const Color(0xFF2F4F4F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 11, color: Color(0xFF696969)),
                      const SizedBox(width: 4),
                      Text(dateStr,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF696969))),
                    ],
                  ),
                ],
              ),
            ),
            // Delete button
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(7),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Colors.redAccent),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? Colors.white38 : const Color(0xFF696969)),
          ],
        ),
      ),
    );
  }
}
