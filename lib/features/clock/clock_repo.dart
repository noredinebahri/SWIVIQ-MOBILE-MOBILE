import '../../core/api/api_client.dart';
import '../../core/models/json_utils.dart';

/// Pointage des professeurs — appels à `/teacher-clock/*`.
///
/// Le verdict (retard, départ anticipé, séance manquée) est calculé par le
/// serveur contre l'emploi du temps en vigueur ; l'app n'affiche que ce qu'il
/// renvoie, pour que web et mobile racontent la même chose.
class ClockSession {
  ClockSession({
    required this.subject,
    required this.levelName,
    required this.group,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.lateMin,
    required this.earlyMin,
    this.clockIn,
    this.clockOut,
  });

  final String subject;
  final String? levelName;
  final String? group;
  final String startTime;
  final String endTime;
  final String status;
  final int lateMin;
  final int earlyMin;
  final String? clockIn;
  final String? clockOut;

  static ClockSession fromJson(Map<String, dynamic> j) => ClockSession(
        subject: j['subject']?.toString() ?? '',
        levelName: j['levelName']?.toString(),
        group: j['group']?.toString(),
        startTime: j['startTime']?.toString() ?? '',
        endTime: j['endTime']?.toString() ?? '',
        status: j['status']?.toString() ?? 'none',
        lateMin: asInt(j['lateMin']),
        earlyMin: asInt(j['earlyMin']),
        clockIn: j['clockIn']?.toString(),
        clockOut: j['clockOut']?.toString(),
      );
}

class ClockEvent {
  ClockEvent({required this.type, required this.time, required this.source, required this.offsite});
  final String type; // in | out
  final String time;
  final String source; // qr | manual
  final bool offsite;

  static ClockEvent fromJson(Map<String, dynamic> j) => ClockEvent(
        type: j['type']?.toString() ?? 'in',
        time: j['time']?.toString() ?? '',
        source: j['source']?.toString() ?? 'qr',
        offsite: j['offsite'] == true,
      );
}

class ClockDay {
  ClockDay({
    required this.date,
    required this.status,
    required this.expectedStart,
    required this.expectedEnd,
    required this.sessionsCount,
    required this.present,
    required this.absent,
    required this.lateMin,
    required this.earlyMin,
    required this.sessions,
    required this.events,
  });

  final String date;
  final String status;
  final String? expectedStart;
  final String? expectedEnd;
  final int sessionsCount;
  final int present;
  final int absent;
  final int lateMin;
  final int earlyMin;
  final List<ClockSession> sessions;
  final List<ClockEvent> events;

  /// Prochain passage logique : sortie si le dernier passage est une entrée.
  String get nextType => events.isNotEmpty && events.last.type == 'in' ? 'out' : 'in';

  static ClockDay fromJson(Map<String, dynamic> j) => ClockDay(
        date: j['date']?.toString() ?? '',
        status: j['status']?.toString() ?? 'none',
        expectedStart: j['expectedStart']?.toString(),
        expectedEnd: j['expectedEnd']?.toString(),
        sessionsCount: asInt(j['sessionsCount']),
        present: asInt(j['present']),
        absent: asInt(j['absent']),
        lateMin: asInt(j['lateMin']),
        earlyMin: asInt(j['earlyMin']),
        sessions: asMapList(j['sessions']).map(ClockSession.fromJson).toList(),
        events: asMapList(j['events']).map(ClockEvent.fromJson).toList(),
      );
}

class ClockScanResult {
  ClockScanResult({required this.type, required this.time, required this.tone, required this.text, required this.day, required this.duplicate});
  final String type;
  final String time;
  final String tone; // ok | warn | danger | info
  final String text;
  final ClockDay day;
  final bool duplicate;
}

class ClockMonth {
  ClockMonth({required this.days, required this.sessions, required this.present, required this.absent, required this.lateMin, required this.earlyMin, required this.lateCount});
  final List<ClockDay> days;
  final int sessions, present, absent, lateMin, earlyMin, lateCount;
}

class ClockRepo {
  ClockRepo._();
  static final instance = ClockRepo._();
  final _api = ApiClient.instance;

  /// Le QR encode une URL `…/pointage/scan?t=<jeton>` ; on accepte aussi le
  /// jeton nu, au cas où l'écran changerait de format.
  static String? tokenFromScan(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final uri = Uri.tryParse(s);
    final t = uri?.queryParameters['t'];
    if (t != null && t.isNotEmpty) return t;
    final parts = s.split('.');
    return parts.length == 4 ? s : null;
  }

  Future<ClockDay> today() async {
    final data = await _api.get('/teacher-clock/me/today');
    final m = data is Map ? Map<String, dynamic>.from(data['day'] as Map) : <String, dynamic>{};
    return ClockDay.fromJson(m);
  }

  Future<ClockScanResult> scan(String token) async {
    final data = await _api.post('/teacher-clock/scan', data: {'token': token});
    final m = Map<String, dynamic>.from(data as Map);
    final ev = Map<String, dynamic>.from(m['event'] as Map? ?? {});
    final fb = Map<String, dynamic>.from(m['feedback'] as Map? ?? {});
    return ClockScanResult(
      type: ev['type']?.toString() ?? 'in',
      time: ev['time']?.toString() ?? '',
      tone: fb['tone']?.toString() ?? 'info',
      text: fb['text']?.toString() ?? '',
      day: ClockDay.fromJson(Map<String, dynamic>.from(m['day'] as Map? ?? {})),
      duplicate: m['duplicate'] == true,
    );
  }

  Future<ClockMonth> month(int month, int year) async {
    final data = await _api.get('/teacher-clock/me', query: {'month': month, 'year': year});
    final m = data is Map ? data : {};
    final t = m['totals'] is Map ? m['totals'] as Map : {};
    return ClockMonth(
      days: asMapList(m['days']).map(ClockDay.fromJson).toList().reversed.toList(),
      sessions: asInt(t['sessions']),
      present: asInt(t['present']),
      absent: asInt(t['absent']),
      lateMin: asInt(t['lateMin']),
      earlyMin: asInt(t['earlyMin']),
      lateCount: asInt(t['lateCount']),
    );
  }
}

/// Libellé et couleur d'un statut, identiques au web.
({String label, int color, int bg}) clockStatusMeta(String status) => switch (status) {
      'present' => (label: 'Présent', color: 0xFF15803D, bg: 0xFFDCFCE7),
      'late' => (label: 'Retard', color: 0xFFB45309, bg: 0xFFFEF3C7),
      'partial' => (label: 'Séance manquée', color: 0xFFC2410C, bg: 0xFFFFEDD5),
      'absent' => (label: 'Absent', color: 0xFFB91C1C, bg: 0xFFFEE2E2),
      'not_clocked' => (label: 'Non pointé', color: 0xFF6D28D9, bg: 0xFFEDE9FE),
      'incomplete' => (label: 'Sortie manquante', color: 0xFF0E7490, bg: 0xFFCFFAFE),
      'pending' => (label: 'En cours', color: 0xFF475569, bg: 0xFFF1F5F9),
      'upcoming' => (label: 'À venir', color: 0xFF64748B, bg: 0xFFF1F5F9),
      'unexpected' => (label: 'Hors emploi du temps', color: 0xFF1D4ED8, bg: 0xFFDBEAFE),
      _ => (label: 'Rien de prévu', color: 0xFF94A3B8, bg: 0xFFF8FAFC),
    };
