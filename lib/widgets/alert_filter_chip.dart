import 'package:flutter/material.dart';

class AlertFilterChip extends StatelessWidget {
  const new({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      labelStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
    );
  }
}
