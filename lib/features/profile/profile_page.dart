import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/services/auth_service.dart';
import '../../core/ui/app_snackbar.dart';
import 'data/profile_service.dart';
import 'edit_profile_page.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_info_tile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.profileService,
    this.auth,
    this.authService,
  });

  final ProfileService? profileService;
  final FirebaseAuth? auth;
  final AuthService? authService;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late ProfileService _profileService;
  late FirebaseAuth _auth;
  late AuthService _authService;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream;

  @override
  void initState() {
    super.initState();
    _bindServices();
  }

  void _bindServices() {
    _profileService = widget.profileService ?? ProfileService();
    _auth = widget.auth ?? FirebaseAuth.instance;
    _authService = widget.authService ?? AuthService();
    _profileStream = _profileService.watchCurrentUserProfile();
  }

  @override
  void didUpdateWidget(ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileService != widget.profileService ||
        oldWidget.auth != widget.auth) {
      _bindServices();
    } else if (oldWidget.authService != widget.authService) {
      _authService = widget.authService ?? AuthService();
    }
  }

  void _openEditProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(profileService: _profileService),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final shouldSignOut =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Sign out?'),
              content: const Text(
                'You will need to sign in again to access your Yening Ecos account.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Sign out'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldSignOut) {
      return;
    }

    try {
      await _authService.signOut();
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      AppSnackBar.showMessage(context, 'Unable to sign out. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No authenticated user found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            onPressed: () {
              _openEditProfile(context);
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profileStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const _ProfileErrorState();
          }

          final data = snapshot.data?.data() ?? <String, dynamic>{};

          final firestoreDisplayName = data['displayName'];

          final firestoreEmail = data['email'];

          final displayName =
              firestoreDisplayName is String &&
                  firestoreDisplayName.trim().isNotEmpty
              ? firestoreDisplayName.trim()
              : user.displayName ?? '';

          final email =
              firestoreEmail is String && firestoreEmail.trim().isNotEmpty
              ? firestoreEmail.trim()
              : user.email ?? '';

          return RefreshIndicator(
            onRefresh: () async {
              await user.reload();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                ProfileHeader(name: displayName, email: email),
                const SizedBox(height: 24),
                _SectionCard(
                  title: 'Account information',
                  icon: Icons.badge_outlined,
                  children: [
                    ProfileInfoTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Full name',
                      value: displayName.isEmpty ? 'Not set' : displayName,
                    ),
                    const SizedBox(height: 14),
                    ProfileInfoTile(
                      icon: Icons.email_outlined,
                      label: 'Email address',
                      value: email.isEmpty ? 'Not available' : email,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Account settings',
                  icon: Icons.settings_outlined,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        leading: const Icon(Icons.notifications_none_rounded),
                        title: const Text('Notification preferences'),
                        subtitle: const Text('Manage how you receive alerts'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onTap: () {
                          AppSnackBar.showComingSoon(
                            context,
                            'Notification preferences',
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        leading: const Icon(Icons.security_outlined),
                        title: const Text('Security'),
                        subtitle: const Text('Manage account security'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onTap: () {
                          AppSnackBar.showComingSoon(context, 'Security');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Session',
                  icon: Icons.login_outlined,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        leading: Icon(
                          Icons.logout_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          'Sign out',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text('Sign out from this device'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onTap: () {
                          _signOut(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load your profile',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
