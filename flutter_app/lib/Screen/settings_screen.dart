import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDarkMode;
    final isAr = provider.locale.languageCode == 'ar';

    const bgDark = Color(0xFF1A2E1A);
    const bgLight = Color(0xFFFFFAFA);
    const cardDark = Color(0xFF243D24);
    const cardLight = Color(0xFFDCDCDC);
    const headerDark = Color(0xFF101E10);
    const headerLight = Color(0xFF2F4F4F);

    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      appBar: AppBar(
        backgroundColor: isDark ? headerDark : headerLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isAr ? 'الإعدادات' : 'Settings',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Appearance ───────────────────────────────
              _SectionTitle(title: isAr ? 'المظهر' : 'Appearance'),
              const SizedBox(height: 12),

              _ToggleTile(
                icon: Icons.dark_mode_rounded,
                label: isAr ? 'الوضع الليلي' : 'Dark Mode',
                value: provider.isDarkMode,
                color: const Color(0xFF9C27B0),
                isDark: isDark,
                cardDark: cardDark,
                cardLight: cardLight,
                onChanged: (val) =>
                    context.read<AppProvider>().toggleDarkMode(val),
              ),
              const SizedBox(height: 10),

              _TapTile(
                icon: Icons.language_rounded,
                label: isAr ? 'اللغة' : 'Language',
                color: const Color(0xFF1A73E8),
                isDark: isDark,
                cardDark: cardDark,
                cardLight: cardLight,
                trailing: Text(
                  isAr ? 'العربية' : 'English',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF696969),
                    fontSize: 13,
                  ),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: isDark ? const Color(0xFF243D24) : Colors.white,
                      title: Text(
                        isAr ? 'اختر اللغة' : 'Select Language',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF2F4F4F),
                        ),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: ['English', 'العربية'].map((lang) {
                          final isSelected =
                              (lang == 'العربية' && isAr) ||
                                  (lang == 'English' && !isAr);
                          return ListTile(
                            title: Text(
                              lang,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF2F4F4F),
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check,
                                    color: Color(0xFF1A73E8))
                                : null,
                            onTap: () {
                              context.read<AppProvider>().setLanguage(lang);
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // ─── Notifications ────────────────────────────
              _SectionTitle(title: isAr ? 'الإشعارات' : 'Notifications'),
              const SizedBox(height: 12),

              _ToggleTile(
                icon: Icons.notifications_rounded,
                label: isAr ? 'إشعارات فورية' : 'Push Notifications',
                value: provider.pushNotifications,
                color: const Color(0xFF00BCD4),
                isDark: isDark,
                cardDark: cardDark,
                cardLight: cardLight,
                onChanged: (val) =>
                    context.read<AppProvider>().togglePushNotifications(val),
              ),
              const SizedBox(height: 10),
              _ToggleTile(
                icon: Icons.email_rounded,
                label: isAr ? 'إشعارات البريد' : 'Email Notifications',
                value: provider.emailNotifications,
                color: const Color(0xFF4CAF50),
                isDark: isDark,
                cardDark: cardDark,
                cardLight: cardLight,
                onChanged: (val) =>
                    context.read<AppProvider>().toggleEmailNotifications(val),
              ),

              const SizedBox(height: 24),

              // ─── App ──────────────────────────────────────
              _SectionTitle(title: isAr ? 'التطبيق' : 'App'),
              const SizedBox(height: 12),

              _ToggleTile(
                icon: Icons.volume_up_rounded,
                label: isAr ? 'الصوت' : 'Sound',
                value: provider.sound,
                color: const Color(0xFFFF9800),
                isDark: isDark,
                cardDark: cardDark,
                cardLight: cardLight,
                onChanged: (val) =>
                    context.read<AppProvider>().toggleSound(val),
              ),
              const SizedBox(height: 10),
              _ToggleTile(
                icon: Icons.vibration_rounded,
                label: isAr ? 'الاهتزاز' : 'Vibration',
                value: provider.vibration,
                color: const Color(0xFFFF5722),
                isDark: isDark,
                cardDark: cardDark,
                cardLight: cardLight,
                onChanged: (val) =>
                    context.read<AppProvider>().toggleVibration(val),
              ),
              const SizedBox(height: 10),
              _TapTile(
                icon: Icons.cleaning_services_rounded,
                label: isAr ? 'مسح الذاكرة المؤقتة' : 'Clear Cache',
                color: Colors.redAccent,
                isDark: isDark,
                cardDark: cardDark,
                cardLight: cardLight,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: isDark ? const Color(0xFF243D24) : Colors.white,
                      title: Text(
                        isAr ? 'مسح الذاكرة' : 'Clear Cache',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF2F4F4F),
                        ),
                      ),
                      content: Text(
                        isAr ? 'هل أنت متأكد؟' : 'Are you sure?',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF696969),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(isAr ? 'إلغاء' : 'Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isAr ? 'تم المسح بنجاح' : 'Cache cleared!',
                                ),
                                backgroundColor: const Color(0xFF1A73E8),
                              ),
                            );
                          },
                          child: Text(
                            isAr ? 'مسح' : 'Clear',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // ─── Support ──────────────────────────────────
              _SectionTitle(title: isAr ? 'الدعم' : 'Support'),
              const SizedBox(height: 12),

              _TapTile(
                icon: Icons.feedback_rounded,
                label: isAr ? 'إرسال ملاحظات' : 'Send Feedback',
                color: const Color(0xFF1A73E8),
                isDark: isDark,
                cardDark: cardDark,
                cardLight: cardLight,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: isDark ? const Color(0xFF243D24) : Colors.white,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => _FeedbackSheet(isDark: isDark),
                  );
                },
              ),
              const SizedBox(height: 10),
              _TapTile(
                icon: Icons.star_rounded,
                label: isAr ? 'تقييم التطبيق' : 'Rate the App',
                color: const Color(0xFFFFD700),
                isDark: isDark,
                cardDark: cardDark,
                cardLight: cardLight,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => _RateDialog(isDark: isDark),
                  );
                },
              ),
              const SizedBox(height: 10),
              _TapTile(
                icon: Icons.info_rounded,
                label: isAr ? 'عن التطبيق' : 'About App',
                color: isDark ? Colors.white54 : const Color(0xFF696969),
                isDark: isDark,
                cardDark: cardDark,
                cardLight: cardLight,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: isDark ? const Color(0xFF243D24) : Colors.white,
                      title: Text(
                        'ARchitect AI',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF2F4F4F),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Version: 1.0.0',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF696969))),
                          const SizedBox(height: 8),
                          Text('Graduation Project 2025',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF696969))),
                          const SizedBox(height: 8),
                          Text(
                            'AI-powered building design app.',
                            style: TextStyle(
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF696969)),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(isAr ? 'إغلاق' : 'Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section Title ────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A73E8),
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─── Toggle Tile ──────────────────────────────────────────────
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final Color color;
  final bool isDark;
  final Color cardDark;
  final Color cardLight;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.cardDark,
    required this.cardLight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? cardDark : cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark
                ? Colors.white12
                : const Color(0xFF696969).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF2F4F4F),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF1A73E8),
          ),
        ],
      ),
    );
  }
}

// ─── Tap Tile ─────────────────────────────────────────────────
class _TapTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final Color cardDark;
  final Color cardLight;
  final VoidCallback onTap;
  final Widget? trailing;

  const _TapTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.cardDark,
    required this.cardLight,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? cardDark : cardLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark
                  ? Colors.white12
                  : const Color(0xFF696969).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF2F4F4F),
                ),
              ),
            ),
            trailing ??
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: isDark ? Colors.white38 : const Color(0xFF696969),
                ),
          ],
        ),
      ),
    );
  }
}

// ─── Feedback Sheet ───────────────────────────────────────────
class _FeedbackSheet extends StatefulWidget {
  final bool isDark;
  const _FeedbackSheet({required this.isDark});

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send Feedback',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white : const Color(0xFF2F4F4F),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            style: TextStyle(
              color: widget.isDark ? Colors.white : const Color(0xFF2F4F4F),
            ),
            decoration: InputDecoration(
              hintText: 'Write your feedback here...',
              hintStyle: TextStyle(
                color: widget.isDark
                    ? Colors.white38
                    : const Color(0xFF696969),
              ),
              filled: true,
              fillColor: widget.isDark
                  ? const Color(0xFF2F4F4F)
                  : const Color(0xFFDCDCDC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Feedback sent!'),
                    backgroundColor: Color(0xFF1A73E8),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Rate Dialog ──────────────────────────────────────────────
class _RateDialog extends StatefulWidget {
  final bool isDark;
  const _RateDialog({required this.isDark});

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor:
          widget.isDark ? const Color(0xFF243D24) : Colors.white,
      title: Text(
        'Rate ARchitect AI',
        style: TextStyle(
          color: widget.isDark ? Colors.white : const Color(0xFF2F4F4F),
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'How would you rate your experience?',
            style: TextStyle(
              color: widget.isDark
                  ? Colors.white54
                  : const Color(0xFF696969),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () => setState(() => _rating = index + 1),
                icon: Icon(
                  index < _rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: const Color(0xFFFFD700),
                  size: 36,
                ),
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Thanks for rating us $_rating stars!'),
                backgroundColor: const Color(0xFF1A73E8),
              ),
            );
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}