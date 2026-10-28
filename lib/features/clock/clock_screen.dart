import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/widgets/common.dart';
import 'clock_repo.dart';
import 'clock_scan_screen.dart';

/// Pointage du professeur : sa journée, le bouton « Scanner », son mois.
///
/// Ouvert aussi par le lien du QR (`/pointage/scan?t=…`) : le jeton est
/// alors envoyé tout de suite, sans passer par la caméra.
class ClockScreen extends ConsumerStatefulWidget {
  const ClockScreen({super.key, this.initialToken});

  /// Jeton reçu par lien profond (appareil photo du téléphone).
  final String? initialToken;

  @override
  ConsumerState<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends ConsumerState<ClockScreen> with SingleTickerProviderStateMixin {
  final _repo = ClockRepo.instance;
  late final TabController _tabs = TabController(length: 2, vsync: this);

  ClockDay? _today;
  bool _loadingToday = true;
  bool _sending = false;
  String? _error;

  ClockMonth? _month;
  bool _loadingMonth = false;
  DateTime _period = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _loadToday();
    _tabs.addListener(() {
      if (_tabs.index == 1 && _month == null) _loadMonth();
    });
    final t = widget.initialToken;
    if (t != null && t.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(t));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadToday() async {
    setState(() => _loadingToday = true);
    try {
      final d = await _repo.today();
      if (mounted) setState(() { _today = d; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Chargement impossible');
    } finally {
      if (mounted) setState(() => _loadingToday = false);
    }
  }

  Future<void> _loadMonth() async {
    setState(() => _loadingMonth = true);
    try {
      final m = await _repo.month(_period.month, _period.year);
      if (mounted) setState(() => _month = m);
    } catch (_) {
      if (mounted) setState(() => _month = ClockMonth(days: const [], sessions: 0, present: 0, absent: 0, lateMin: 0, earlyMin: 0, lateCount: 0));
    } finally {
      if (mounted) setState(() => _loadingMonth = false);
    }
  }

  Future<void> _openScanner() async {
    final token = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ClockScanScreen(), fullscreenDialog: true),
    );
    if (token != null) await _send(token);
  }

  Future<void> _send(String token) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final r = await _repo.scan(token);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() { _today = r.day; _month = null; });
      await _showResult(r);
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      final reason = e is ApiException && e.body is Map ? (e.body as Map)['reason']?.toString() : null;
      final text = switch (reason) {
        'expired' => 'Ce QR a expiré. L’écran en affiche un nouveau : rescannez.',
        'offsite' => 'Vous n’êtes pas sur le wifi du centre. Connectez-vous puis rescannez.',
        'wrong_center' => 'Ce QR appartient à un autre centre.',
        'bad_signature' || 'malformed' => 'QR illisible : rescannez l’écran de l’accueil.',
        _ => e is ApiException ? e.message : 'Pointage impossible. Réessayez ou prévenez l’accueil.',
      };
      await _showError(text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showResult(ClockScanResult r) {
    final (color, icon) = switch (r.tone) {
      'ok' => (const Color(0xFF16A34A), Icons.check_circle_rounded),
      'warn' => (const Color(0xFFF59E0B), Icons.schedule_rounded),
      'danger' => (const Color(0xFFDC2626), Icons.error_rounded),
      _ => (AppColors.primary600, Icons.info_rounded),
    };
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22)),
              child: Icon(icon, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 14),
            Text(r.type == 'in' ? 'ENTRÉE ENREGISTRÉE' : 'SORTIE ENREGISTRÉE',
                style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 12, color: AppColors.secondary600)),
            Text(r.time, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, height: 1.1)),
            const SizedBox(height: 8),
            Text(r.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (r.duplicate) ...[
              const SizedBox(height: 6),
              const Text('Passage déjà enregistré il y a moins d’une minute.', style: TextStyle(color: AppColors.secondary500, fontSize: 12)),
            ],
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))),
          ],
        ),
      ),
    );
  }

  Future<void> _showError(String text) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: AppColors.danger500, borderRadius: BorderRadius.circular(22)),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 14),
              const Text('POINTAGE REFUSÉ', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 12, color: AppColors.secondary600)),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () { Navigator.pop(ctx); _openScanner(); }, child: const Text('Rescanner'))),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon pointage'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Aujourd’hui'), Tab(text: 'Mon mois')]),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TodayTab(
            day: _today,
            loading: _loadingToday,
            sending: _sending,
            error: _error,
            userName: user?.fullName ?? '',
            onScan: _openScanner,
            onRefresh: _loadToday,
          ),
          _MonthTab(
            month: _month,
            loading: _loadingMonth,
            period: _period,
            onShift: (d) { setState(() { _period = DateTime(_period.year, _period.month + d); _month = null; }); _loadMonth(); },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Aujourd'hui ───────────────────────────

class _TodayTab extends StatelessWidget {
  const _TodayTab({
    required this.day, required this.loading, required this.sending, required this.error,
    required this.userName, required this.onScan, required this.onRefresh,
  });
  final ClockDay? day;
  final bool loading, sending;
  final String? error;
  final String userName;
  final VoidCallback onScan;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final d = day;
    final next = d?.nextType ?? 'in';
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bouton principal
          OxCard(
            color: const Color(0xFF0B0B0F),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  next == 'in' ? 'Vous arrivez ?' : 'Vous partez ?',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  next == 'in' ? 'Scannez le QR de l’accueil pour pointer votre entrée.' : 'Scannez le QR de l’accueil pour pointer votre sortie.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    onPressed: sending ? null : onScan,
                    icon: sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.qr_code_scanner_rounded, size: 26),
                    label: Text(sending ? 'Envoi…' : (next == 'in' ? 'Scanner · Entrée' : 'Scanner · Sortie')),
                  ),
                ),
                const SizedBox(height: 10),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_rounded, color: Colors.white54, size: 16),
                    SizedBox(width: 6),
                    Text('Depuis le wifi du centre uniquement', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (loading && d == null) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (error != null && d == null)
            OxCard(child: Row(children: [const Icon(Icons.cloud_off_rounded, color: AppColors.danger500), const SizedBox(width: 10), Expanded(child: Text(error!))])),

          if (d != null) ...[
            _DayCard(day: d, title: 'Aujourd’hui'),
          ],
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.title});
  final ClockDay day;
  final String title;

  @override
  Widget build(BuildContext context) {
    final meta = clockStatusMeta(day.status);
    return OxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              StatusBadge(label: meta.label, color: Color(meta.color), background: Color(meta.bg)),
            ],
          ),
          if (day.expectedStart != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Attendu ${day.expectedStart} → ${day.expectedEnd} · ${day.sessionsCount} séance${day.sessionsCount > 1 ? 's' : ''}',
                  style: const TextStyle(color: AppColors.secondary500, fontSize: 12)),
            ),
          const SizedBox(height: 10),
          if (day.sessions.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Aucune séance prévue dans l’emploi du temps.', style: TextStyle(color: AppColors.secondary500))),
          for (final s in day.sessions) _SessionRow(s: s),
          if (day.events.isNotEmpty) ...[
            const Divider(height: 18),
            Wrap(
              spacing: 8, runSpacing: 6,
              children: [
                for (final e in day.events)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: e.type == 'in' ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(e.type == 'in' ? Icons.login_rounded : Icons.logout_rounded, size: 14, color: e.type == 'in' ? const Color(0xFF166534) : const Color(0xFF9A3412)),
                        const SizedBox(width: 4),
                        Text(e.time, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: e.type == 'in' ? const Color(0xFF166534) : const Color(0xFF9A3412))),
                        if (e.source == 'manual') const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.edit_rounded, size: 11, color: AppColors.secondary500)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.s});
  final ClockSession s;

  @override
  Widget build(BuildContext context) {
    final meta = clockStatusMeta(s.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.startTime, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(s.endTime, style: const TextStyle(color: AppColors.secondary500, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.subject, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text([s.levelName, s.group].whereType<String>().where((x) => x.isNotEmpty).join(' · '), style: const TextStyle(color: AppColors.secondary500, fontSize: 12)),
                if (s.lateMin > 0 || s.earlyMin > 0)
                  Text([if (s.lateMin > 0) '+${s.lateMin} min', if (s.earlyMin > 0) '−${s.earlyMin} min'].join('  '),
                      style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ),
          ),
          StatusBadge(label: meta.label, color: Color(meta.color), background: Color(meta.bg)),
        ],
      ),
    );
  }
}

// ─────────────────────────── Mon mois ───────────────────────────

class _MonthTab extends StatelessWidget {
  const _MonthTab({required this.month, required this.loading, required this.period, required this.onShift});
  final ClockMonth? month;
  final bool loading;
  final DateTime period;
  final void Function(int) onShift;

  @override
  Widget build(BuildContext context) {
    final m = month;
    final judged = (m?.present ?? 0) + (m?.absent ?? 0);
    final rate = judged == 0 ? null : ((m!.present / judged) * 100).round();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(onPressed: () => onShift(-1), icon: const Icon(Icons.chevron_left_rounded)),
            SizedBox(width: 170, child: Text(DateFormat.yMMMM('fr').format(period), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            IconButton(onPressed: () => onShift(1), icon: const Icon(Icons.chevron_right_rounded)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _Kpi(label: 'Présence', value: rate == null ? '—' : '$rate %')),
            const SizedBox(width: 8),
            Expanded(child: _Kpi(label: 'Séances', value: '${m?.present ?? 0}/${m?.sessions ?? 0}')),
            const SizedBox(width: 8),
            Expanded(child: _Kpi(label: 'Retards', value: '${m?.lateCount ?? 0}', sub: '${m?.lateMin ?? 0} min', warn: true)),
          ],
        ),
        const SizedBox(height: 12),
        if (loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        if (!loading && m != null && m.days.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune séance ni passage ce mois.', style: TextStyle(color: AppColors.secondary500)))),
        if (m != null)
          for (final d in m.days) ...[
            _DayCard(day: d, title: DateFormat('EEE d MMM', 'fr').format(DateTime.parse(d.date))),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, this.sub, this.warn = false});
  final String label, value;
  final String? sub;
  final bool warn;

  @override
  Widget build(BuildContext context) => OxCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.secondary500, letterSpacing: .6)),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: warn ? const Color(0xFFB45309) : null)),
            if (sub != null) Text(sub!, style: const TextStyle(fontSize: 11, color: AppColors.secondary500)),
          ],
        ),
      );
}
