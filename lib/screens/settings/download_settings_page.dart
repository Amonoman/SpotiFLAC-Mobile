import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:spotiflac_android/providers/settings_provider.dart';
import 'package:spotiflac_android/widgets/settings_group.dart';

class DownloadSettingsPage extends ConsumerWidget {
  const DownloadSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Collapsing App Bar with back button
          SliverAppBar(
            expandedHeight: 120 + topPadding,
            collapsedHeight: kToolbarHeight,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = 120 + topPadding;
                final minHeight = kToolbarHeight + topPadding;
                final expandRatio = ((constraints.maxHeight - minHeight) / (maxHeight - minHeight)).clamp(0.0, 1.0);
                final animation = AlwaysStoppedAnimation(expandRatio);
                return FlexibleSpaceBar(
                  expandedTitleScale: 1.0,
                  titlePadding: EdgeInsets.zero,
                  title: SafeArea(
                    child: Container(
                      alignment: Alignment.bottomLeft,
                      padding: EdgeInsets.only(
                        left: Tween<double>(begin: 56, end: 24).evaluate(animation),
                        bottom: Tween<double>(begin: 12, end: 16).evaluate(animation),
                      ),
                      child: Text('Download',
                        style: TextStyle(
                          fontSize: Tween<double>(begin: 20, end: 28).evaluate(animation),
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Service section
          const SliverToBoxAdapter(child: SettingsSectionHeader(title: 'Service')),
          SliverToBoxAdapter(
            child: SettingsGroup(
              children: [
                _ServiceSelector(
                  currentService: settings.defaultService,
                  onChanged: (service) => ref.read(settingsProvider.notifier).setDefaultService(service),
                ),
              ],
            ),
          ),

          // Quality section
          const SliverToBoxAdapter(child: SettingsSectionHeader(title: 'Audio Quality')),
          SliverToBoxAdapter(
            child: SettingsGroup(
              children: [
                SettingsSwitchItem(
                  icon: Icons.tune,
                  title: 'Ask Before Download',
                  subtitle: 'Choose quality for each download',
                  value: settings.askQualityBeforeDownload,
                  onChanged: (value) => ref.read(settingsProvider.notifier).setAskQualityBeforeDownload(value),
                ),
                if (!settings.askQualityBeforeDownload) ...[
                  _QualityOption(
                    title: 'FLAC Lossless',
                    subtitle: '16-bit / 44.1kHz',
                    isSelected: settings.audioQuality == 'LOSSLESS',
                    onTap: () => ref.read(settingsProvider.notifier).setAudioQuality('LOSSLESS'),
                  ),
                  _QualityOption(
                    title: 'Hi-Res FLAC',
                    subtitle: '24-bit / up to 96kHz',
                    isSelected: settings.audioQuality == 'HI_RES',
                    onTap: () => ref.read(settingsProvider.notifier).setAudioQuality('HI_RES'),
                  ),
                  _QualityOption(
                    title: 'Hi-Res FLAC Max',
                    subtitle: '24-bit / up to 192kHz',
                    isSelected: settings.audioQuality == 'HI_RES_LOSSLESS',
                    onTap: () => ref.read(settingsProvider.notifier).setAudioQuality('HI_RES_LOSSLESS'),
                    showDivider: false,
                  ),
                ],
              ],
            ),
          ),

          // File settings section
          const SliverToBoxAdapter(child: SettingsSectionHeader(title: 'File Settings')),
          SliverToBoxAdapter(
            child: SettingsGroup(
              children: [
                SettingsItem(
                  icon: Icons.text_fields,
                  title: 'Filename Format',
                  subtitle: settings.filenameFormat,
                  onTap: () => _showFormatEditor(context, ref, settings.filenameFormat),
                ),
                SettingsItem(
                  icon: Icons.folder_outlined,
                  title: 'Download Directory',
                  subtitle: settings.downloadDirectory.isEmpty ? 'Music/SpotiFLAC' : settings.downloadDirectory,
                  onTap: () => _pickDirectory(ref),
                ),
                SettingsItem(
                  icon: Icons.create_new_folder_outlined,
                  title: 'Folder Organization',
                  subtitle: _getFolderOrganizationLabel(settings.folderOrganization),
                  onTap: () => _showFolderOrganizationPicker(context, ref, settings.folderOrganization),
                  showDivider: false,
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  void _showFormatEditor(BuildContext context, WidgetRef ref, String current) {
    final controller = TextEditingController(text: current);
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Filename Format', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: controller, decoration: const InputDecoration(hintText: '{artist} - {title}'), autofocus: true),
          const SizedBox(height: 16),
          Text('Available: {title}, {artist}, {album}, {track}, {year}, {disc}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(onPressed: () { ref.read(settingsProvider.notifier).setFilenameFormat(controller.text); Navigator.pop(context); }, child: const Text('Save')),
          ]),
        ]),
      ),
    );
  }

  Future<void> _pickDirectory(WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) ref.read(settingsProvider.notifier).setDownloadDirectory(result);
  }

  String _getFolderOrganizationLabel(String value) {
    switch (value) {
      case 'artist':
        return 'By Artist';
      case 'album':
        return 'By Album';
      case 'artist_album':
        return 'By Artist & Album';
      default:
        return 'None';
    }
  }

  void _showFolderOrganizationPicker(BuildContext context, WidgetRef ref, String current) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text('Folder Organization', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text('Organize downloaded files into folders', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
            ),
            _FolderOption(
              title: 'None',
              subtitle: 'All files in download folder',
              example: 'SpotiFLAC/Track.flac',
              isSelected: current == 'none',
              onTap: () { ref.read(settingsProvider.notifier).setFolderOrganization('none'); Navigator.pop(context); },
            ),
            _FolderOption(
              title: 'By Artist',
              subtitle: 'Separate folder for each artist',
              example: 'SpotiFLAC/Artist Name/Track.flac',
              isSelected: current == 'artist',
              onTap: () { ref.read(settingsProvider.notifier).setFolderOrganization('artist'); Navigator.pop(context); },
            ),
            _FolderOption(
              title: 'By Album',
              subtitle: 'Separate folder for each album',
              example: 'SpotiFLAC/Album Name/Track.flac',
              isSelected: current == 'album',
              onTap: () { ref.read(settingsProvider.notifier).setFolderOrganization('album'); Navigator.pop(context); },
            ),
            _FolderOption(
              title: 'By Artist & Album',
              subtitle: 'Nested folders for artist and album',
              example: 'SpotiFLAC/Artist/Album/Track.flac',
              isSelected: current == 'artist_album',
              onTap: () { ref.read(settingsProvider.notifier).setFolderOrganization('artist_album'); Navigator.pop(context); },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ServiceSelector extends StatelessWidget {
  final String currentService;
  final ValueChanged<String> onChanged;
  const _ServiceSelector({required this.currentService, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        _ServiceChip(icon: Icons.music_note, label: 'Tidal', isSelected: currentService == 'tidal', onTap: () => onChanged('tidal')),
        const SizedBox(width: 8),
        _ServiceChip(icon: Icons.album, label: 'Qobuz', isSelected: currentService == 'qobuz', onTap: () => onChanged('qobuz')),
        const SizedBox(width: 8),
        _ServiceChip(icon: Icons.shopping_bag, label: 'Amazon', isSelected: currentService == 'amazon', onTap: () => onChanged('amazon')),
      ]),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ServiceChip({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final unselectedColor = isDark 
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.05), colorScheme.surface)
        : colorScheme.surfaceContainerHigh;
    
    return Expanded(
      child: Material(
        color: isSelected ? colorScheme.primaryContainer : unselectedColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Icon(icon, color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _QualityOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showDivider;
  const _QualityOption({required this.title, required this.subtitle, required this.isSelected, required this.onTap, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 2),
                      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                isSelected 
                    ? Icon(Icons.check_circle, color: colorScheme.primary)
                    : Icon(Icons.circle_outlined, color: colorScheme.outline),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 20,
            endIndent: 20,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
      ],
    );
  }
}

class _FolderOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String example;
  final bool isSelected;
  final VoidCallback onTap;
  const _FolderOption({required this.title, required this.subtitle, required this.example, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 4),
          Text(example, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: colorScheme.primary)),
        ],
      ),
      trailing: isSelected ? Icon(Icons.check_circle, color: colorScheme.primary) : Icon(Icons.circle_outlined, color: colorScheme.outline),
      onTap: onTap,
    );
  }
}
