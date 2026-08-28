import 'json_utils.dart';

/// Modèles de l'emploi du temps (lecture seule côté mobile).
class ScheduleConfig {
  ScheduleConfig({
    required this.id,
    required this.name,
    this.isActive = false,
    this.startDate,
    this.endDate,
  });

  final int id;
  final String name;
  final bool isActive;
  final String? startDate;
  final String? endDate;

  factory ScheduleConfig.fromJson(Map<String, dynamic> j) => ScheduleConfig(
        id: asInt(j['id']),
        name: j['name']?.toString() ?? '',
        isActive: j['isActive'] == true || j['isActive'] == 1,
        startDate: j['startDate']?.toString(),
        endDate: j['endDate']?.toString(),
      );
}

class ScheduleSlot {
  ScheduleSlot({
    required this.id,
    required this.day,
    required this.subject,
    required this.startTime,
    required this.endTime,
    this.group,
    this.room,
    this.levelId,
    this.levelName,
    this.userId,
    this.teacherName,
  });

  final int id;

  /// Jour en français : "Lundi" … "Samedi" (format du backend).
  final String day;
  final String subject;

  /// "HH:MM"
  final String startTime;
  final String endTime;
  final String? group;

  /// Code salle A..E ; C = grande, D = biblio, E = cuisine.
  final String? room;
  final int? levelId;
  final String? levelName;
  final int? userId;
  final String? teacherName;

  String get roomLabel => switch (room) {
        'C' => 'Grande salle',
        'D' => 'Bibliothèque',
        'E' => 'Cuisine',
        null => '',
        _ => 'Salle $room',
      };

  factory ScheduleSlot.fromJson(Map<String, dynamic> j) {
    String? teacherName;
    if (j['user'] is Map) {
      final u = j['user'] as Map;
      teacherName =
          '${u['firstname'] ?? ''} ${u['lastname'] ?? ''}'.trim();
    }
    return ScheduleSlot(
      id: asInt(j['id']),
      day: j['day']?.toString() ?? '',
      subject: j['subject']?.toString() ?? '',
      startTime: j['startTime']?.toString() ?? '',
      endTime: j['endTime']?.toString() ?? '',
      group: j['group']?.toString(),
      room: j['room']?.toString(),
      levelId: asIntOrNull(j['levelId']),
      levelName: j['level'] is Map ? j['level']['name']?.toString() : null,
      userId: asIntOrNull(j['userId']),
      teacherName: teacherName?.isEmpty == true ? null : teacherName,
    );
  }
}

const kScheduleDays = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];
