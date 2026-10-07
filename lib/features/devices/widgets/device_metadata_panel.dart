import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/local_time_format.dart';
import '../models/device_details.dart';
import '../services/device_details_service.dart';

class DeviceMetadataPanel extends StatelessWidget {
  const DeviceMetadataPanel({
    super.key,
    required this.state,
    required this.onRetry,
  });

  final DeviceDetailsState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.isLoading) {
      return _Notice(
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Loading device information…',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    final details = state.details;
    if (details == null) {
      return _Notice(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.message ?? 'Device information is unavailable.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry device information'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (details.description != null) ...[
          _Notice(
            child: Text(
              details.description!,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 10),
        ],
        for (final section in details.sections) ...[
          _MetadataSection(section: section),
          const SizedBox(height: 10),
        ],
        if (state.typeLoading)
          const _Notice(child: Text('Loading model specifications…')),
        if (state.typeUnavailable)
          _Notice(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Model specifications are unavailable. Retry to load them.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry specifications'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MetadataSection extends StatelessWidget {
  const _MetadataSection({required this.section});

  final DeviceMetadataSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
      ),
    );
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('metadata-${section.id}'),
        initiallyExpanded: section.initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          section.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: Icon(
          _sectionIcon(section.id),
          color: theme.colorScheme.primary,
          size: 20,
        ),
        children: [
          for (final field in section.fields) _MetadataRow(field: field),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.field});

  final DeviceMetadataField field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = field.timestamp == null
        ? field.value!
        : formatLocalDateTime12(field.timestamp!);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final copyButton = field.copyable
              ? IconButton(
                  tooltip: 'Copy ${field.label.toLowerCase()}',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${field.label} copied')),
                    );
                  },
                )
              : null;
          if (constraints.maxWidth < 420 * scale) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: content),
                ?copyButton,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: constraints.maxWidth * 0.4,
                child: Text(
                  field.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
              ?copyButton,
            ],
          );
        },
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: child,
    );
  }
}

IconData _sectionIcon(String id) => switch (id) {
  'overview' => Icons.info_outline_rounded,
  'firmware' => Icons.system_update_alt_rounded,
  'hardware' => Icons.memory_rounded,
  'lifecycle' => Icons.history_rounded,
  'reference' => Icons.badge_outlined,
  _ when id.startsWith('sensor-') => Icons.sensors_rounded,
  _ when id.startsWith('control-') => Icons.toggle_on_outlined,
  _ => Icons.info_outline_rounded,
};
