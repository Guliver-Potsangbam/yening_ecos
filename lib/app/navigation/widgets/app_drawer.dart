import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yening_ecos/core/ui/app_snackbar.dart';

import '../../../features/settings/settings_page.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.currentIndex,
    required this.onPrimaryDestinationSelected,
    required this.onProfileSelected,
    required this.onSignOut,
  });

  final int currentIndex;

  final ValueChanged<int> onPrimaryDestinationSelected;

  final VoidCallback onProfileSelected;

  final VoidCallback onSignOut;

  String get _userName {
    final user = FirebaseAuth.instance.currentUser;

    final displayName = user?.displayName?.trim();

    if (displayName == null || displayName.isEmpty) {
      return 'Yening Ecos User';
    }

    return displayName;
  }

  String get _userEmail {
    return FirebaseAuth.instance.currentUser?.email ?? '';
  }

  String get _initials {
    final name = _userName.trim();

    if (name.isEmpty) {
      return 'YE';
    }

    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length == 1) {
      final value = parts.first;

      return value.substring(0, value.length >= 2 ? 2 : 1).toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  void _selectPrimaryDestination(BuildContext context, int index) {
    Navigator.of(context).pop();

    if (currentIndex == index) {
      return;
    }

    onPrimaryDestinationSelected(index);
  }

  void _selectProfile(BuildContext context) {
    Navigator.of(context).pop();

    onProfileSelected();
  }

  void _selectSettings(BuildContext context) {
    Navigator.of(context).pop();

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  void _selectHelp(BuildContext context) {
    Navigator.of(context).pop();

    AppSnackBar.showComingSoon(context, 'Help & Support');
  }

  void _selectAbout(BuildContext context) {
    Navigator.of(context).pop();

    showAboutDialog(
      context: context,
      applicationName: 'Yening Ecos',
      applicationVersion: '1.0.0',
      applicationLegalese: '© Yening Technology and Innovation Private Limited',
    );
  }

  void _selectSignOut(BuildContext context) {
    Navigator.of(context).pop();

    onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return NavigationDrawer(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        _selectPrimaryDestination(context, index);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(17),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    if (_userEmail.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _userEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              Icon(Icons.hub_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Yening Ecos',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),

        const Divider(),

        const NavigationDrawerDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: Text('Home'),
        ),

        const NavigationDrawerDestination(
          icon: Icon(Icons.devices_outlined),
          selectedIcon: Icon(Icons.devices_rounded),
          label: Text('Devices'),
        ),

        const NavigationDrawerDestination(
          icon: Icon(Icons.notifications_none_rounded),
          selectedIcon: Icon(Icons.notifications_rounded),
          label: Text('Alerts'),
        ),

        const Divider(),

        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 16, 8),
          child: Text(
            'Account',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        ListTile(
          leading: const Icon(Icons.person_outline_rounded),
          title: const Text('Profile'),
          onTap: () {
            _selectProfile(context);
          },
        ),

        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          onTap: () {
            _selectSettings(context);
          },
        ),

        const Divider(),

        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 16, 8),
          child: Text(
            'Support',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        ListTile(
          leading: const Icon(Icons.help_outline_rounded),
          title: const Text('Help & Support'),
          onTap: () {
            _selectHelp(context);
          },
        ),

        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('About Yening Ecos'),
          onTap: () {
            _selectAbout(context);
          },
        ),

        const Divider(),

        ListTile(
          leading: Icon(Icons.logout_rounded, color: colorScheme.error),
          title: Text(
            'Sign out',
            style: TextStyle(
              color: colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: () {
            _selectSignOut(context);
          },
        ),
      ],
    );
  }
}
