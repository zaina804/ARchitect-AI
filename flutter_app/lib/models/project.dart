import 'dart:convert';

class Project {
  final String id;
  final String title;
  final String imagePath;
  final String glbName;
  final DateTime date;
  final Map<String, dynamic>? bounds;

  const Project({
    required this.id,
    required this.title,
    required this.imagePath,
    required this.glbName,
    required this.date,
    this.bounds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'imagePath': imagePath,
        'glbName': glbName,
        'dateMs': date.millisecondsSinceEpoch,
        'bounds': bounds,
      };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        title: j['title'] as String,
        imagePath: j['imagePath'] as String,
        glbName: j['glbName'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(j['dateMs'] as int),
        bounds: j['bounds'] as Map<String, dynamic>?,
      );

  static String encodeList(List<Project> list) =>
      jsonEncode(list.map((p) => p.toJson()).toList());

  static List<Project> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
  }
}
