import 'package:flutter/material.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/ui/remote/widgets/remote_button.dart';

/// Circular D-pad with 4 direction buttons + centre OK.
/// Scales the ring to fit available height (up to 260 px).
/// Back and Home row always fills the parent width below the ring.
class DPadWidget extends StatelessWidget {
  final void Function(RemoteCommand) onCommand;

  const DPadWidget({super.key, required this.onCommand});

  @override
  Widget build(BuildContext context) {
    const Color ringColor    = Color(0xFF1E1E26);
    const Color purpleAccent = Color(0xFF8B5CF6);
    const Color iconColor    = Color(0xFFD4D4D8);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        // Ring diameter: at most 260, but leave 80 px for the bottom row + gap.
        // Minimum is 120 px so the widget never overflows on small screens or
        // when the soft keyboard is partially open.
        final ringSize = (constraints.maxHeight - 80 - 16)
            .clamp(120.0, 260.0);

        // Wrap in ClipRect so any residual overflow is silently clipped
        // instead of triggering a red stripe error in debug mode.
        return ClipRect(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── D-pad ring ────────────────────────────────────────────────
            Center(
              child: Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ringColor,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: ringSize * 0.04,
                      child: _DirBtn(
                        icon: Icons.keyboard_arrow_up_rounded,
                        size: ringSize * 0.27,
                        onTap: () => onCommand(RemoteCommand.up),
                      ),
                    ),
                    Positioned(
                      bottom: ringSize * 0.04,
                      child: _DirBtn(
                        icon: Icons.keyboard_arrow_down_rounded,
                        size: ringSize * 0.27,
                        onTap: () => onCommand(RemoteCommand.down),
                      ),
                    ),
                    Positioned(
                      left: ringSize * 0.04,
                      child: _DirBtn(
                        icon: Icons.keyboard_arrow_left_rounded,
                        size: ringSize * 0.27,
                        onTap: () => onCommand(RemoteCommand.left),
                      ),
                    ),
                    Positioned(
                      right: ringSize * 0.04,
                      child: _DirBtn(
                        icon: Icons.keyboard_arrow_right_rounded,
                        size: ringSize * 0.27,
                        onTap: () => onCommand(RemoteCommand.right),
                      ),
                    ),

                    // Centre OK
                    Container(
                      width: ringSize * 0.31,
                      height: ringSize * 0.31,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: purpleAccent.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: RemoteButton.circle(
                        size: ringSize * 0.31,
                        color: purpleAccent,
                        onTap: () => onCommand(RemoteCommand.ok),
                        child: Container(
                          width: ringSize * 0.09,
                          height: ringSize * 0.09,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Back / Home row — full parent width ───────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RemoteButton(
                  width: 80, height: 52,
                  color: const Color(0xFF22222A),
                  borderRadius: BorderRadius.circular(26),
                  onTap: () => onCommand(RemoteCommand.back),
                  child: const Icon(Icons.arrow_back_rounded, color: iconColor, size: 22),
                ),
                RemoteButton(
                  width: 80, height: 52,
                  color: const Color(0xFF22222A),
                  borderRadius: BorderRadius.circular(26),
                  onTap: () => onCommand(RemoteCommand.home),
                  child: const Icon(Icons.home_outlined, color: iconColor, size: 24),
                ),
              ],
            ),
          ],
        ));
      },
    );
  }
}

class _DirBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _DirBtn({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return RemoteButton.circle(
      size: size,
      color: Colors.transparent,
      isFlat: true,
      border: Border.all(color: Colors.transparent),
      onTap: onTap,
      child: Icon(icon, size: size * 0.56, color: const Color(0xFF8A8A93)),
    );
  }
}
