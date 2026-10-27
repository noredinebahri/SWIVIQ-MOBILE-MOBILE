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
    this.levelGroupId,
    this.levelGroupName,
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
  /// Une séance vise SOIT une branche (`levelId`), SOIT un niveau supérieur
  /// (`levelGroupId`, toutes ses branches) — jamais les deux (cf. backend
  /// schedule.model.js). Un écran qui ne lit que `levelId` perd donc toutes
  /// les séances « 2ᵉ Bac » : elles n'ont pas de niveau, mais un groupe.
  final int? levelId;
  final String? levelName;
  final int? levelGroupId;
  final String? levelGroupName;
  final int? userId;
  final String? teacherName;

  /// Libellé de ce que la séance concerne : le niveau supérieur, ou la
  /// branche isolée. Jamais vide si le backend a renseigné l'un des deux.
  String get scopeLabel {
    final g = (levelGroupName ?? '').trim();
    if (g.isNotEmpty) return g;
    return (levelName ?? '').trim();
  }

  /// La séance concerne-t-elle ce niveau supérieur (directement, ou via une
  /// de ses branches dont les ids sont fournis) ?
  bool matchesScope({int? levelGroupId, List<int> levelIds = const []}) {
    if (levelGroupId != null && this.levelGroupId == levelGroupId) return true;
    return levelId != null && levelIds.contains(levelId);
  }

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
      levelGroupId: asIntOrNull(j['levelGroupId'] ?? j['level_group_id']),
      levelGroupName:
          j['levelGroup'] is Map ? j['levelGroup']['name']?.toString() : null,
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
