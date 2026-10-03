import 'package:flutter/material.dart';

import '../auth/models/user_profile.dart';
import '../auth/services/auth_service.dart';
import '../auth/services/user_profile_service.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthService();
  final _userProfileService = UserProfileService();

  bool _isSigningOut = false;

  Future<void> _editProfile() async {
    final updated = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const EditProfilePage()));

    if (!mounted || updated != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully.')),
    );
  }

  Future<void> _signOut() async {
    if (_isSigningOut) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });

    try {
      await _authService.signOut();
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSigningOut = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to sign out: $e')));
    }
  }

  String _initials(String? displayName, String email) {
    final name = displayName?.trim() ?? '';

    if (name.isNotEmpty) {
      final parts = name
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();

      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }

      return parts.first[0].toUpperCase();
    }

    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }

    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<UserProfile?>(
      stream: _userProfileService.watchProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load your profile.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = snapshot.data;

        final displayName =
            profile?.displayName?.trim() ?? user.displayName?.trim();

        final email = profile?.email ?? user.email ?? '';

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      child: Text(
                        _initials(displayName, email),
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName?.isNotEmpty == true
                                ? displayName!
                                : 'Your name',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit profile',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Account',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 10),

            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const Text('Personal information'),
                    subtitle: const Text(
                      'Manage your name and account information',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _editProfile,
                  ),

                  const Divider(height: 1, indent: 16, endIndent: 16),

                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email address'),
                    subtitle: Text(email),
                  ),

                  const Divider(height: 1, indent: 16, endIndent: 16),

                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: const Text('Change password'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Account status',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 10),

            const Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.verified_user_outlined),
                title: Text('Account active'),
                subtitle: Text('Your account is in good standing.'),
                trailing: Icon(Icons.check_circle_outline_rounded),
              ),
            ),

            const SizedBox(height: 24),

            FilledButton.tonalIcon(
              onPressed: _isSigningOut ? null : _signOut,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _isSigningOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_rounded),
              label: Text(_isSigningOut ? 'Signing out...' : 'Sign out'),
            ),
          ],
        );
      },
    );
  }
}
