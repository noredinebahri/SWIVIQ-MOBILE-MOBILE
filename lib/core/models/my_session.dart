import 'json_utils.dart';

/// Séance du professeur connecté d'après l'emploi du temps en vigueur
/// (GET /absence/my-sessions?date=). Le pointage se fait sur UNE séance :
/// niveau supérieur, branches, groupe et matière en découlent.
class MySession {
  MySession({
    required this.slotId,
    required this.subject,
    required this.matterId,
    required this.matterName,
    required this.levelGroupId,
    required this.levelId,
    required this.levelIds,
    required this.levelName,
    required this.group,
    required this.groupIndex,
    required this.room,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  final int slotId;
  final String subject;
  final int? matterId;
  final String? matterName;
  final int? levelGroupId;
  final int? levelId;
  final List<int> levelIds;
  final String? levelName;
  final String? group;
  final int? groupIndex;
  final String? room;
  final String startTime;
  final String endTime;

  /// now | upcoming | past | scheduled (jour autre qu'aujourd'hui).
  final String status;

  bool get isNow => status == 'now';

  String get statusLabel => switch (status) {
        'now' => 'En cours',
        'upcoming' => 'À venir',
        'past' => 'Terminée',
        _ => 'Prévue',
      };

  factory MySession.fromJson(Map<String, dynamic> j) => MySession(
        slotId: asInt(j['slotId']),
        subject: j['subject']?.toString() ?? '',
        matterId: asIntOrNull(j['matterId']),
        matterName: asStringOrNull(j['matterName']),
        levelGroupId: asIntOrNull(j['levelGroupId']),
        levelId: asIntOrNull(j['levelId']),
        levelIds: (j['levelIds'] as List? ?? []).map(asInt).toList(),
        levelName: asStringOrNull(j['levelName']),
        group: asStringOrNull(j['group']),
        groupIndex: asIntOrNull(j['groupIndex']),
        room: asStringOrNull(j['room']),
        startTime: j['startTime']?.toString() ?? '',
        endTime: j['endTime']?.toString() ?? '',
        status: j['status']?.toString() ?? 'scheduled',
      );
}
