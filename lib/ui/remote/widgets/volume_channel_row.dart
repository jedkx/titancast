import 'package:flutter/material.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/ui/remote/widgets/remote_button.dart';

/// Middle row: VOL rocker | 2×2 grid (mic, source, settings, mute) | CH rocker
///
/// The mic button is always the top-left button regardless of brand.
/// Voice search integration is handled by [onMicTap].
class VolumeChannelRow extends StatelessWidget {
  final void Function(RemoteCommand) onCommand;
  final VoidCallback? onMicTap;

  const VolumeChannelRow({
    super.key,
    required this.onCommand,
    this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color btnColor  = Color(0xFF22222A);
    const Color iconColor = Color(0xFFD4D4D8);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // VOL rocker
        _RockerPill(
          label: 'VOL',
          topIcon: Icons.add_rounded,
          bottomIcon: Icons.remove_rounded,
          onTop: () => onCommand(RemoteCommand.volumeUp),
          onBottom: () => onCommand(RemoteCommand.volumeDown),
        ),

        // 2×2 grid
        SizedBox(
          width: 128,
          height: 148,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Mic / voice search — always visible, all brands
                  RemoteButton(
                    width: 58,
                    height: 58,
                    color: btnColor,
                    onTap: onMicTap ?? () {},
                    child: const Icon(
                      Icons.mic_none_rounded,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  RemoteButton(
                    width: 58,
                    height: 58,
                    color: btnColor,
                    onTap: () => onCommand(RemoteCommand.source),
                    child: const Icon(Icons.input_rounded, color: iconColor, size: 24),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Settings → menu command (opens Options on Philips)
                  RemoteButton(
                    width: 58,
                    height: 58,
                    color: btnColor,
                    onTap: () => onCommand(RemoteCommand.menu),
                    child: const Icon(Icons.settings_outlined, color: iconColor, size: 24),
                  ),
                  RemoteButton(
                    width: 58,
                    height: 58,
                    color: btnColor,
                    onTap: () => onCommand(RemoteCommand.mute),
                    child: const Icon(Icons.volume_off_outlined, color: iconColor, size: 24),
                  ),
                ],
              ),
            ],
          ),
        ),

        // CH rocker
        _RockerPill(
          label: 'CH',
          topIcon: Icons.keyboard_arrow_up_rounded,
          bottomIcon: Icons.keyboard_arrow_down_rounded,
          onTop: () => onCommand(RemoteCommand.channelUp),
          onBottom: () => onCommand(RemoteCommand.channelDown),
        ),
      ],
    );
  }
}

class _RockerPill extends StatelessWidget {
  final String label;
  final IconData topIcon;
  final IconData bottomIcon;
  final VoidCallback onTop;
  final VoidCallback onBottom;

  const _RockerPill({
    required this.label,
    required this.topIcon,
    required this.bottomIcon,
    required this.onTop,
    required this.onBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 148,
      decoration: BoxDecoration(
        color: const Color(0xFF15151A),
        borderRadius: BorderRadius.circular(31),
        border: Border.all(color: Colors.white.withValues(alpha: 0.02), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RemoteButton.circle(
            size: 54,
            color: const Color(0xFF22222A),
            onTap: onTop,
            child: Icon(topIcon, color: Colors.white, size: 24),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8A8A93),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          RemoteButton.circle(
            size: 54,
            color: const Color(0xFF22222A),
            onTap: onBottom,
            child: Icon(bottomIcon, color: const Color(0xFF8B5CF6), size: 24),
          ),
        ],
      ),
    );
  }
}
