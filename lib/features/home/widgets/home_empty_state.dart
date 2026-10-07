import 'package:flutter/material.dart';

import '../../../widgets/app_empty_state.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Your environment',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
        ),
        const SizedBox(height: 24),
        const AppEmptyState(
          icon: Icons.sensors_rounded,
          title: 'No devices yet',
          description: 'Add your first device from the Devices tab to see its details and live sensor readings here.',
        ),
      ],
    ),
  );
}
