import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project.dart';

class AppProvider extends ChangeNotifier {
  bool   _isDarkMode          = true;
  Locale _locale              = const Locale('en');
  bool   _pushNotifications   = true;
  bool   _emailNotifications  = false;
  bool   _sound               = true;
  bool   _vibration           = true;
  List<Project> _projects     = [];

  // ── User profile ──────────────────────────────────────────────────────────
  String _userName     = 'User';
  String _userEmail    = 'user@email.com';
  String _userPhone    = '+962 XX XXX XXXX';
  String _userLocation = 'Jordan';

  bool   get isDarkMode          => _isDarkMode;
  Locale get locale              => _locale;
  bool   get pushNotifications   => _pushNotifications;
  bool   get emailNotifications  => _emailNotifications;
  bool   get sound               => _sound;
  bool   get vibration           => _vibration;
  List<Project> get projects     => _projects;
  String get userName            => _userName;
  String get userEmail           => _userEmail;
  String get userPhone           => _userPhone;
  String get userLocation        => _userLocation;

  AppProvider() {
    _loadProjects();
    _loadProfile();
  }

  // ── Projects ──────────────────────────────────────────────────────────────

  Future<void> _loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('projects');
    if (raw != null && raw.isNotEmpty) {
      try {
        _projects = Project.decodeList(raw);
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<void> addProject(Project project) async {
    _projects.insert(0, project);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('projects', Project.encodeList(_projects));
  }

  Future<void> removeProject(String id) async {
    _projects.removeWhere((p) => p.id == id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('projects', Project.encodeList(_projects));
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _userName     = prefs.getString('userName')     ?? 'User';
    _userEmail    = prefs.getString('userEmail')    ?? 'user@email.com';
    _userPhone    = prefs.getString('userPhone')    ?? '+962 XX XXX XXXX';
    _userLocation = prefs.getString('userLocation') ?? 'Jordan';
    notifyListeners();
  }

  Future<void> setUserName(String val) async {
    _userName = val.isEmpty ? 'User' : val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', _userName);
  }

  Future<void> setUserEmail(String val) async {
    _userEmail = val.isEmpty ? 'user@email.com' : val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userEmail', _userEmail);
  }

  Future<void> setUserPhone(String val) async {
    _userPhone = val.isEmpty ? '+962 XX XXX XXXX' : val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userPhone', _userPhone);
  }

  Future<void> setUserLocation(String val) async {
    _userLocation = val.isEmpty ? 'Jordan' : val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userLocation', _userLocation);
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  void toggleDarkMode(bool val) {
    _isDarkMode = val;
    notifyListeners();
  }

  void togglePushNotifications(bool val) {
    _pushNotifications = val;
    notifyListeners();
  }

  void toggleEmailNotifications(bool val) {
    _emailNotifications = val;
    notifyListeners();
  }

  void toggleSound(bool val) {
    _sound = val;
    notifyListeners();
  }

  void toggleVibration(bool val) {
    _vibration = val;
    notifyListeners();
  }

  void setLanguage(String lang) {
    _locale = lang == 'العربية' ? const Locale('ar') : const Locale('en');
    notifyListeners();
  }
}
