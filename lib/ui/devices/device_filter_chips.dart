import 'package:flutter/material.dart';
import '../../../discovery/discovery_model.dart';

class DeviceFilterChips extends StatelessWidget {
  final DeviceType? activeFilter;
  final void Function(DeviceType?) onChanged;

  const DeviceFilterChips({
    super.key,
    required this.activeFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _Chip(
            label: 'TVs',
            icon: Icons.tv_rounded,
            selected: activeFilter == DeviceType.tv,
            onTap: () => onChanged(DeviceType.tv),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Speakers',
            icon: Icons.speaker_group_rounded,
            selected: activeFilter == DeviceType.speaker,
            onTap: () => onChanged(DeviceType.speaker),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Other',
            icon: Icons.devices_other_rounded,
            selected: activeFilter == DeviceType.other,
            onTap: () => onChanged(DeviceType.other),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, size: 16),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}