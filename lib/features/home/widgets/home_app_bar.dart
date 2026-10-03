import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key, required this.title, required this.isHome});

  final String title;
  final bool isHome;

  @override
  Size get preferredSize => Size.fromHeight(isHome ? 80 : 76);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppBar(
      automaticallyImplyLeading: true,
      toolbarHeight: isHome ? 80 : 76,
      elevation: 1.5,
      scrolledUnderElevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.16),
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      titleSpacing: 8,
      title: Text(
        title,
        style: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
