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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF8B5CF6).withValues(alpha: 0.15) : const Color(0xFF15151A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF8B5CF6).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? const Color(0xFF8B5CF6) : const Color(0xFF8A8A93)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF8B5CF6) : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}