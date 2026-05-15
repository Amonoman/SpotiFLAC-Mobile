import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:spotiflac_android/services/app_remote_config_service.dart';

class AppAnnouncementDialog extends StatelessWidget {
  final RemoteAnnouncement announcement;
  final VoidCallback onDismiss;

  const AppAnnouncementDialog({
    super.key,
    required this.announcement,
    required this.onDismiss,
  });

  Future<void> _openCta(BuildContext context) async {
    final ctaUrl = announcement.ctaUrl;
    if (ctaUrl == null || ctaUrl.isEmpty) return;

    final uri = Uri.tryParse(ctaUrl);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
    onDismiss();
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUrgent = announcement.priority.toLowerCase() == 'high';

    return AlertDialog(
      icon: Icon(
        isUrgent ? Icons.priority_high_rounded : Icons.campaign_rounded,
        color: isUrgent ? colorScheme.error : colorScheme.primary,
      ),
      title: Text(announcement.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(
          child: Text(
            announcement.message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            onDismiss();
            Navigator.pop(context);
          },
          child: Text(
            announcement.dismissible
                ? MaterialLocalizations.of(context).closeButtonLabel
                : 'OK',
          ),
        ),
        if (announcement.hasCta)
          FilledButton(
            onPressed: () => _openCta(context),
            child: Text(announcement.ctaLabel!),
          ),
      ],
    );
  }
}

Future<void> showAppAnnouncementDialog(
  BuildContext context, {
  required RemoteAnnouncement announcement,
  required VoidCallback onDismiss,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: announcement.dismissible,
    builder: (context) =>
        AppAnnouncementDialog(announcement: announcement, onDismiss: onDismiss),
  ).whenComplete(onDismiss);
}
