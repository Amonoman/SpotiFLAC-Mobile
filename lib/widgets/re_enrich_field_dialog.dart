import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Field group keys matching the Go backend `update_fields` values.
class ReEnrichFields {
  static const String cover = 'cover';
  static const String lyrics = 'lyrics';
  static const String basicTags = 'basic_tags';
  static const String trackInfo = 'track_info';
  static const String releaseInfo = 'release_info';
  static const String extra = 'extra';

  static const List<String> all = [
    cover,
    lyrics,
    basicTags,
    trackInfo,
    releaseInfo,
    extra,
  ];
}

/// Result returned by the re-enrich field selection sheet.
class ReEnrichFieldSelection {
  final List<String> fields;
  const ReEnrichFieldSelection(this.fields);

  /// True when every available field is selected (or update_fields can be omitted).
  bool get isAll => fields.length == ReEnrichFields.all.length;
}

Future<ReEnrichFieldSelection?> showReEnrichFieldDialog(
  BuildContext context, {
  required int selectedCount,
}) {
  return showModalBottomSheet<ReEnrichFieldSelection>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _ReEnrichFieldSheet(selectedCount: selectedCount),
  );
}

class _ReEnrichFieldSheet extends StatefulWidget {
  final int selectedCount;
  const _ReEnrichFieldSheet({required this.selectedCount});

  @override
  State<_ReEnrichFieldSheet> createState() => _ReEnrichFieldSheetState();
}

class _ReEnrichFieldSheetState extends State<_ReEnrichFieldSheet> {
  final Set<String> _selected = Set<String>.from(ReEnrichFields.all);

  bool get _allSelected => _selected.length == ReEnrichFields.all.length;

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        _selected.addAll(ReEnrichFields.all);
      } else {
        _selected.clear();
      }
    });
  }

  void _toggle(String field, bool? value) {
    setState(() {
      if (value == true) {
        _selected.add(field);
      } else {
        _selected.remove(field);
      }
    });
  }

  String _labelFor(String field, AppLocalizations l10n) {
    switch (field) {
      case ReEnrichFields.cover:
        return l10n.trackReEnrichFieldCover;
      case ReEnrichFields.lyrics:
        return l10n.trackReEnrichFieldLyrics;
      case ReEnrichFields.basicTags:
        return l10n.trackReEnrichFieldBasicTags;
      case ReEnrichFields.trackInfo:
        return l10n.trackReEnrichFieldTrackInfo;
      case ReEnrichFields.releaseInfo:
        return l10n.trackReEnrichFieldReleaseInfo;
      case ReEnrichFields.extra:
        return l10n.trackReEnrichFieldExtra;
      default:
        return field;
    }
  }

  IconData _iconFor(String field) {
    switch (field) {
      case ReEnrichFields.cover:
        return Icons.image_outlined;
      case ReEnrichFields.lyrics:
        return Icons.lyrics_outlined;
      case ReEnrichFields.basicTags:
        return Icons.album_outlined;
      case ReEnrichFields.trackInfo:
        return Icons.format_list_numbered;
      case ReEnrichFields.releaseInfo:
        return Icons.calendar_today_outlined;
      case ReEnrichFields.extra:
        return Icons.label_outline;
      default:
        return Icons.tag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text(
              l10n.trackReEnrich,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text(
              l10n.trackReEnrichOnlineSubtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l10n.downloadedAlbumSelectedCount(widget.selectedCount),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(
              l10n.trackReEnrichSelectAll,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            value: _allSelected,
            tristate: true,
            onChanged: _toggleAll,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          for (final field in ReEnrichFields.all)
            CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: Icon(_iconFor(field), size: 20),
              title: Text(_labelFor(field, l10n)),
              value: _selected.contains(field),
              onChanged: (v) => _toggle(field, v),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(
                        context,
                        ReEnrichFieldSelection(_selected.toList()),
                      ),
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: Text(l10n.trackReEnrich),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
