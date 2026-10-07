import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../widgets/app_empty_state.dart';
import '../../profile/data/profile_service.dart';
import 'home_feature_card.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.onAddDevice,
    this.profileService,
  });

  final VoidCallback onAddDevice;
  final ProfileService? profileService;

  ProfileService get _profile => profileService ?? ProfileService();

  String _getFirstName(String displayName) {
    final normalizedName = displayName.trim();

    if (normalizedName.isEmpty) {
      return 'there';
    }

    final parts = normalizedName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'there';
    }

    return parts.first;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profile.watchCurrentUserProfile(),
      builder: (context, snapshot) {
        final user = FirebaseAuth.instance.currentUser;

        final data = snapshot.data?.data();

        final firestoreName = data?['displayName'];

        final displayName =
            firestoreName is String && firestoreName.trim().isNotEmpty
            ? firestoreName.trim()
            : user?.displayName ?? '';

        final firstName = _getFirstName(displayName);

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                'Welcome $firstName',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Yening Ecos environment starts here.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              AppEmptyState(
                icon: Icons.sensors_rounded,
                title: 'Connect your first device',
                description: 'Add a Yening Ecos device to start monitoring your environment and using connected controls.',
                actionLabel: 'Add Device',
                onAction: onAddDevice,
              ),
              const SizedBox(height: 20),
              const HomeFeatureCard(
                icon: Icons.insights_rounded,
                title: 'Monitor your environment',
                description: 'View live sensor readings and understand the conditions around your connected devices.',
              ),
              const SizedBox(height: 12),
              const HomeFeatureCard(
                icon: Icons.notifications_none_rounded,
                title: 'Stay informed',
                description: 'Receive alerts when something important needs your attention.',
              ),
              const SizedBox(height: 12),
              const HomeFeatureCard(
                icon: Icons.tune_rounded,
                title: 'Control connected devices',
                description: 'Use supported controls from your Yening Ecos app when your devices are connected.',
              ),
              const SizedBox(height: 20),
              _HomeFooterCard(),
            ],
          ),
        );
      },
    );
  }
}

class _HomeFooterCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Connect a device to unlock your live Yening Ecos experience.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
