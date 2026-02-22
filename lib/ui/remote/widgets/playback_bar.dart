import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/ui/remote/widgets/remote_button.dart';

class PlaybackBar extends StatelessWidget {
  final void Function(RemoteCommand) onCommand;

  const PlaybackBar({super.key, required this.onCommand});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      // Arka plandaki keskin gölge ile süzülme hissi (Floating effect)
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MediaBtn(
                  icon: Icons.fast_rewind_rounded,
                  onTap: () => onCommand(RemoteCommand.rewind),
                ),
                _MediaBtn(
                  icon: Icons.stop_rounded,
                  onTap: () => onCommand(RemoteCommand.stop),
                ),

                // Play Butonu - Etrafında hafif bir Accent Glow var
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: RemoteButton.circle(
                    size: 56,
                    color: colorScheme.primary,
                    onTap: () => onCommand(RemoteCommand.play),
                    child: Icon(Icons.play_arrow_rounded, color: colorScheme.onPrimary, size: 28),
                  ),
                ),

                _MediaBtn(
                  icon: Icons.pause_rounded,
                  onTap: () => onCommand(RemoteCommand.pause),
                ),
                _MediaBtn(
                  icon: Icons.fast_forward_rounded,
                  onTap: () => onCommand(RemoteCommand.fastForward),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MediaBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return RemoteButton.circle(
      size: 48,
      color: Colors.transparent,
      onTap: onTap,
      child: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
        size: 24,
      ),
    );
  }
}