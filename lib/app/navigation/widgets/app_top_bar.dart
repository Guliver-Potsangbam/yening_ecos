import 'package:flutter/material.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onMenuPressed,
    required this.onProfilePressed,
  });

  final String title;
  final String subtitle;
  final VoidCallback onMenuPressed;
  final VoidCallback onProfilePressed;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      toolbarHeight: 76,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.14),
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      leadingWidth: 64,
      leading: IconButton(
        tooltip: 'Open menu',
        onPressed: onMenuPressed,
        icon: const Icon(Icons.menu_rounded),
      ),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(5),
            child: Image.asset(
              'assets/icon/app_top_bar_icon.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Profile',
          onPressed: onProfilePressed,
          icon: const Icon(Icons.person_outline_rounded),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
