import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _locationCtrl;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppProvider>();
    _nameCtrl     = TextEditingController(text: p.userName);
    _emailCtrl    = TextEditingController(text: p.userEmail);
    _phoneCtrl    = TextEditingController(text: p.userPhone);
    _locationCtrl = TextEditingController(text: p.userLocation);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = context.read<AppProvider>();
    await p.setUserName(_nameCtrl.text.trim());
    await p.setUserEmail(_emailCtrl.text.trim());
    await p.setUserPhone(_phoneCtrl.text.trim());
    await p.setUserLocation(_locationCtrl.text.trim());
    if (mounted) setState(() => _editing = false);
  }

  void _cancelEdit() {
    final p = context.read<AppProvider>();
    _nameCtrl.text     = p.userName;
    _emailCtrl.text    = p.userEmail;
    _phoneCtrl.text    = p.userPhone;
    _locationCtrl.text = p.userLocation;
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark   = provider.isDarkMode;
    final isAr     = provider.locale.languageCode == 'ar';

    const bgDark     = Color(0xFF1A2E1A);
    const bgLight    = Color(0xFFFFFAFA);
    const cardDark   = Color(0xFF243D24);
    const cardLight  = Color(0xFFDCDCDC);
    const headerDark = Color(0xFF101E10);
    const headerLight = Color(0xFF2F4F4F);
    const textDark   = Colors.white;
    const textLight  = Color(0xFF2F4F4F);

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
          isAr ? 'ملفي الشخصي' : 'My Profile',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              tooltip: isAr ? 'تعديل' : 'Edit',
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // ── Avatar ────────────────────────────────────────────────────
              Stack(
                children: [
                  const CircleAvatar(
                    radius: 55,
                    backgroundColor: Color(0xFF1A73E8),
                    child: Icon(Icons.person, size: 55, color: Colors.white),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A73E8), shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                provider.userName,
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold,
                  color: isDark ? textDark : textLight,
                ),
              ),
              Text(
                provider.userEmail,
                style: const TextStyle(fontSize: 14, color: Color(0xFF696969)),
              ),
              const SizedBox(height: 32),

              // ── Fields (view or edit) ──────────────────────────────────────
              if (_editing) ...[
                _EditField(
                  label: isAr ? 'الاسم الكامل' : 'Full Name',
                  ctrl: _nameCtrl,
                  icon: Icons.person_outline_rounded,
                  isDark: isDark, cardDark: cardDark, cardLight: cardLight,
                ),
                const SizedBox(height: 14),
                _EditField(
                  label: isAr ? 'البريد الإلكتروني' : 'Email',
                  ctrl: _emailCtrl,
                  icon: Icons.email_outlined,
                  isDark: isDark, cardDark: cardDark, cardLight: cardLight,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _EditField(
                  label: isAr ? 'الهاتف' : 'Phone',
                  ctrl: _phoneCtrl,
                  icon: Icons.phone_outlined,
                  isDark: isDark, cardDark: cardDark, cardLight: cardLight,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _EditField(
                  label: isAr ? 'الموقع' : 'Location',
                  ctrl: _locationCtrl,
                  icon: Icons.location_on_outlined,
                  isDark: isDark, cardDark: cardDark, cardLight: cardLight,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancelEdit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : const Color(0xFF2F4F4F),
                          side: BorderSide(
                            color: isDark ? Colors.white24
                                         : const Color(0xFF696969).withOpacity(0.4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(isAr ? 'إلغاء' : 'Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A73E8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          isAr ? 'حفظ' : 'Save',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _InfoField(
                  label: isAr ? 'الاسم الكامل' : 'Full Name',
                  value: provider.userName,
                  isDark: isDark, cardDark: cardDark, cardLight: cardLight,
                ),
                const SizedBox(height: 14),
                _InfoField(
                  label: isAr ? 'البريد الإلكتروني' : 'Email',
                  value: provider.userEmail,
                  isDark: isDark, cardDark: cardDark, cardLight: cardLight,
                ),
                const SizedBox(height: 14),
                _InfoField(
                  label: isAr ? 'الهاتف' : 'Phone',
                  value: provider.userPhone,
                  isDark: isDark, cardDark: cardDark, cardLight: cardLight,
                ),
                const SizedBox(height: 14),
                _InfoField(
                  label: isAr ? 'الموقع' : 'Location',
                  value: provider.userLocation,
                  isDark: isDark, cardDark: cardDark, cardLight: cardLight,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: Text(
                      isAr ? 'تعديل الملف الشخصي' : 'Edit Profile',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Read-only field ────────────────────────────────────────────────────────────
class _InfoField extends StatelessWidget {
  final String label;
  final String value;
  final bool   isDark;
  final Color  cardDark;
  final Color  cardLight;

  const _InfoField({
    required this.label, required this.value,
    required this.isDark, required this.cardDark, required this.cardLight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? cardDark : cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFF696969).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF696969))),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF2F4F4F),
                    )),
              ],
            ),
          ),
          Icon(Icons.edit, size: 16,
              color: isDark ? Colors.white38 : const Color(0xFF696969)),
        ],
      ),
    );
  }
}

// ── Editable field ────────────────────────────────────────────────────────────
class _EditField extends StatelessWidget {
  final String              label;
  final TextEditingController ctrl;
  final IconData            icon;
  final bool                isDark;
  final Color               cardDark;
  final Color               cardLight;
  final TextInputType       keyboardType;

  const _EditField({
    required this.label, required this.ctrl, required this.icon,
    required this.isDark, required this.cardDark, required this.cardLight,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? cardDark : cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF1A73E8).withOpacity(0.5),
        ),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white : const Color(0xFF2F4F4F),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF696969)),
          prefixIcon: Icon(icon, size: 20,
              color: isDark ? Colors.white38 : const Color(0xFF696969)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
