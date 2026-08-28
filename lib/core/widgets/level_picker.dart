import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/reference.dart';

/// Sélecteur de niveau organisé par NIVEAU SUPÉRIEUR (hiérarchie du centre) :
/// chaque niveau supérieur est une section, ses niveaux (branches) en dessous.
/// Les niveaux sans rattachement apparaissent dans « Autres niveaux ».
///
/// Retourne le [Level] choisi, ou null si annulé.
Future<Level?> showLevelHierarchyPicker(
  BuildContext context, {
  required List<Level> levels,
  required List<LevelGroup> groups,
  int? selectedId,
  String title = 'Choisir un niveau',
}) {
  final actifs = levels.where((l) => l.actif == 1).toList();
  final byGroup = <int, List<Level>>{};
  final ungrouped = <Level>[];
  for (final l in actifs) {
    if (l.levelGroupId != null &&
        groups.any((g) => g.id == l.levelGroupId)) {
      byGroup.putIfAbsent(l.levelGroupId!, () => []).add(l);
    } else {
      ungrouped.add(l);
    }
  }

  return showModalBottomSheet<Level>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                title,
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final g in groups)
              if ((byGroup[g.id] ?? []).isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.account_tree_rounded,
                          size: 16, color: AppColors.primary600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          g.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final l in byGroup[g.id]!)
                  ListTile(
                    contentPadding:
                        const EdgeInsets.only(left: 44, right: 20),
                    dense: true,
                    leading:
                        const Icon(Icons.school_outlined, size: 20),
                    title: Text(l.displayName),
                    selected: l.id == selectedId,
                    trailing: l.id == selectedId
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary600)
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(l),
                  ),
              ],
            if (ungrouped.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Icon(Icons.more_horiz_rounded,
                        size: 16, color: AppColors.secondary400),
                    SizedBox(width: 8),
                    Text(
                      'Autres niveaux',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary400,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              for (final l in ungrouped)
                ListTile(
                  contentPadding:
                      const EdgeInsets.only(left: 44, right: 20),
                  dense: true,
                  leading: const Icon(Icons.school_outlined, size: 20),
                  title: Text(l.displayName),
                  selected: l.id == selectedId,
                  trailing: l.id == selectedId
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary600)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(l),
                ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
