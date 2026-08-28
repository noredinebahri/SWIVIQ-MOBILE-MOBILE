import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/json_utils.dart';
import '../../core/models/schedule.dart';
import '../../core/widgets/common.dart';

/// Professeur de l'élève, tel que renvoyé par /student/portal/teachers.
class MyTeacher {
  MyTeacher({
    required this.id,
    required this.name,
    required this.subjects,
    required this.slots,
    this.phone,
    this.phoneShared = false,
    this.specialties,
  });

  final int id;
  final String name;
  final List<String> subjects;
  final List<TeacherSlot> slots;

  /// null si le professeur n'a pas autorisé le partage de son numéro.
  final String? phone;
  final bool phoneShared;
  final String? specialties;

  factory MyTeacher.fromJson(Map<String, dynamic> j) => MyTeacher(
        id: asInt(j['id']),
        name: j['name']?.toString() ?? '',
        phone: asStringOrNull(j['phone']),
        phoneShared: asBool(j['phoneShared']),
        specialties: asStringOrNull(j['specialties']),
        subjects: (j['subjects'] as List? ?? [])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        slots: (j['slots'] as List? ?? [])
            .whereType<Map>()
            .map((e) => TeacherSlot.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class TeacherSlot {
  TeacherSlot({
    required this.day,
    required this.startTime,
    required this.endTime,
    this.subject,
    this.room,
  });

  final String day;
  final String startTime;
  final String endTime;
  final String? subject;
  final String? room;

  factory TeacherSlot.fromJson(Map<String, dynamic> j) => TeacherSlot(
        day: j['day']?.toString() ?? '',
        startTime: j['startTime']?.toString() ?? '',
        endTime: j['endTime']?.toString() ?? '',
        subject: asStringOrNull(j['subject']),
        room: asStringOrNull(j['room']),
      );
}

/// Horaire de sortie du collège/lycée déclaré par l'élève.
class SchoolDay {
  SchoolDay({required this.day, this.startTime, this.endTime});

  final String day;
  String? startTime;
  String? endTime;

  factory SchoolDay.fromJson(Map<String, dynamic> j) => SchoolDay(
        day: j['day']?.toString() ?? '',
        startTime: asStringOrNull(j['startTime']),
        endTime: asStringOrNull(j['endTime']),
      );
}

class StudentExtrasRepo {
  static final _api = ApiClient.instance;

  static Future<List<MyTeacher>> teachers() async {
    final data = await _api.get('/student/portal/teachers');
    return asMapList(data).map(MyTeacher.fromJson).toList();
  }

  static Future<List<SchoolDay>> schoolSchedule() async {
    final data = await _api.get('/student/portal/school-schedule');
    return asMapList(data).map(SchoolDay.fromJson).toList();
  }

  /// Enregistre les horaires : un jour sans heure de sortie est supprimé.
  static Future<void> saveSchoolSchedule(List<SchoolDay> days) async {
    await _api.post('/student/portal/school-schedule', data: {
      'schedules': [
        for (final d in days)
          {
            'day': d.day,
            'startTime': d.startTime ?? '08:00',
            'endTime': d.endTime,
          },
      ],
    });
  }
}

/// Écran « Mes professeurs » : uniquement ceux qui enseignent à cet élève.
class MyTeachersScreen extends StatefulWidget {
  const MyTeachersScreen({super.key});

  @override
  State<MyTeachersScreen> createState() => _MyTeachersScreenState();
}

class _MyTeachersScreenState extends State<MyTeachersScreen> {
  List<MyTeacher>? _teachers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await StudentExtrasRepo.teachers();
      if (!mounted) return;
      setState(() => _teachers = list);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de charger vos professeurs.');
    }
  }

  Future<void> _call(String phone) async {
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _whatsapp(String phone) async {
    var p = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (p.startsWith('0')) p = '212${p.substring(1)}';
    await launchUrl(Uri.parse('https://wa.me/$p'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes professeurs')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
    if (_teachers == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_teachers!.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 70),
          EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'Aucun professeur',
            subtitle:
                'Vos professeurs apparaîtront ici dès que vos cours seront planifiés.',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _teachers!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final t = _teachers![i];
        return OxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(name: t.name, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        if (t.subjects.isNotEmpty)
                          Text(
                            t.subjects.join(' · '),
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.secondary400),
                          ),
                      ],
                    ),
                  ),
                  // Contact direct seulement si le professeur l'a autorisé.
                  if (t.phone != null) ...[
                    IconButton(
                      tooltip: 'Appeler',
                      icon: const Icon(Icons.call_rounded,
                          color: AppColors.success600),
                      onPressed: () => _call(t.phone!),
                    ),
                    IconButton(
                      tooltip: 'WhatsApp',
                      icon: const Icon(Icons.chat_rounded,
                          color: Color(0xFF25D366)),
                      onPressed: () => _whatsapp(t.phone!),
                    ),
                  ],
                ],
              ),
              if (t.phone != null) ...[
                const SizedBox(height: 6),
                Text(t.phone!,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary600)),
              ] else ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        size: 14, color: AppColors.secondary400),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Numéro non partagé — contactez le centre.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary400,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ],
              if (t.slots.isNotEmpty) ...[
                const Divider(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in t.slots)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary500.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${s.day} ${s.startTime}-${s.endTime}'
                          '${(s.room ?? '').isNotEmpty ? ' · ${s.room}' : ''}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary700),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Écran « Ma sortie de l'école » : l'élève déclare l'heure à laquelle il
/// quitte son collège/lycée chaque jour. Ces horaires remontent au centre et
/// servent à construire un emploi du temps qui ne chevauche pas l'école.
class SchoolExitScreen extends StatefulWidget {
  const SchoolExitScreen({super.key});

  @override
  State<SchoolExitScreen> createState() => _SchoolExitScreenState();
}

class _SchoolExitScreenState extends State<SchoolExitScreen> {
  final Map<String, SchoolDay> _days = {
    for (final d in kScheduleDays) d: SchoolDay(day: d),
  };
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await StudentExtrasRepo.schoolSchedule();
      if (!mounted) return;
      setState(() {
        for (final r in rows) {
          final existing = _days[r.day];
          if (existing != null) {
            existing.startTime = r.startTime;
            existing.endTime = r.endTime;
          }
        }
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger vos horaires.';
        _loading = false;
      });
    }
  }

  Future<void> _pickTime(SchoolDay day) async {
    final parts = (day.endTime ?? '17:00').split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 17,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Heure de sortie — ${day.day}',
    );
    if (picked == null) return;
    setState(() {
      day.endTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      day.startTime ??= '08:00';
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await StudentExtrasRepo.saveSchoolSchedule(_days.values.toList());
      if (!mounted) return;
      showSnack(context,
          'Horaires enregistrés — merci, cela aide le centre à planifier vos cours.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Enregistrement impossible.', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ma sortie de l\'école')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Enregistrer mes horaires'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary500.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 18, color: AppColors.primary600),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Indiquez à quelle heure vous quittez votre collège ou '
                              'lycée chaque jour. Le centre s\'en sert pour placer vos '
                              'cours après votre sortie — laissez vide les jours sans école.',
                              style: TextStyle(fontSize: 13, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final day in kScheduleDays) _dayRow(_days[day]!),
                    const SizedBox(height: 20),
                  ],
                ),
    );
  }

  Widget _dayRow(SchoolDay day) {
    final set = (day.endTime ?? '').isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: set
            ? AppColors.success100
            : (Theme.of(context).brightness == Brightness.dark
                ? AppColors.secondary700.withValues(alpha: 0.3)
                : AppColors.secondary100),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              day.day,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              set ? 'Sortie à ${day.endTime}' : 'Pas d\'école',
              style: TextStyle(
                color: set ? AppColors.success600 : AppColors.secondary400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (set)
            IconButton(
              tooltip: 'Effacer',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => setState(() => day.endTime = null),
            ),
          FilledButton.tonal(
            onPressed: () => _pickTime(day),
            child: Text(set ? 'Modifier' : 'Choisir'),
          ),
        ],
      ),
    );
  }
}
