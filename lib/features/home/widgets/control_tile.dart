import 'package:flutter/material.dart';

import 'package:yening_ecos/features/devices/models/device_models.dart';

class ControlTile extends StatefulWidget {
  const ControlTile({
    super.key,
    required this.control,
    required this.initiallyEnabled,
  });

  final ControlDefinition control;
  final bool initiallyEnabled;

  @override
  State<ControlTile> createState() => _ControlTileState();
}

class _ControlTileState extends State<ControlTile> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initiallyEnabled;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.control.type == ControlType.button) {
      return ListTile(
        leading: Icon(widget.control.icon),
        title: Text(widget.control.name),
        subtitle: Text(widget.control.description),
        trailing: FilledButton.tonal(
          onPressed: () {},
          child: const Text('Test'),
        ),
      );
    }

    return SwitchListTile(
      secondary: Icon(widget.control.icon),
      title: Text(widget.control.name),
      subtitle: Text(widget.control.description),
      value: _enabled,
      onChanged: (value) {
        setState(() {
          _enabled = value;
        });
      },
    );
  }
}
